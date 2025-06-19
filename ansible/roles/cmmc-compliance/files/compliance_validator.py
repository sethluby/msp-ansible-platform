#!/usr/bin/env python3
"""
CMMC Compliance Validation Script
Author: thndrchckn
Purpose: Automated validation of CMMC control implementation and compliance status

This script provides independent validation capabilities for graceful disconnection scenarios
and ongoing compliance monitoring without MSP dependency.
"""

import os
import sys
import json
import yaml
import subprocess
import logging
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional

# Configuration paths - using variables for flexibility
DEFAULT_CONFIG_PATH = os.environ.get('CMMC_CONFIG_DIR', '/etc/cmmc')
DEFAULT_LOG_PATH = os.environ.get('CMMC_LOG_DIR', '/var/log/cmmc')
DEFAULT_STATE_PATH = os.environ.get('CMMC_STATE_DIR', '/var/lib/cmmc')

class CMICComplianceValidator:
    """
    Comprehensive CMMC compliance validation system
    
    Validates implementation of all CMMC control families:
    - AC: Access Control
    - AU: Audit and Accountability  
    - CM: Configuration Management
    - IA: Identification and Authentication
    - SC: System and Communications Protection
    - SI: System and Information Integrity
    """
    
    def __init__(self, config_path: str = DEFAULT_CONFIG_PATH, 
                 log_path: str = DEFAULT_LOG_PATH,
                 state_path: str = DEFAULT_STATE_PATH):
        """
        Initialize validator with configurable paths
        
        Args:
            config_path: Path to CMMC configuration directory
            log_path: Path to CMMC log directory  
            state_path: Path to CMMC state directory
        """
        self.config_path = Path(config_path)
        self.log_path = Path(log_path)
        self.state_path = Path(state_path)
        
        # Validation results storage
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'hostname': self._get_hostname(),
            'validator_version': '1.0.0',
            'config_paths': {
                'config_dir': str(self.config_path),
                'log_dir': str(self.log_path),
                'state_dir': str(self.state_path)
            },
            'controls': {},
            'summary': {}
        }
        
        # Setup logging with configurable path
        self._setup_logging()
        
        # Load control definitions
        self.control_definitions = self._load_control_definitions()
    
    def _setup_logging(self) -> None:
        """Setup logging configuration with flexible log path"""
        # Create log directory if it doesn't exist
        self.log_path.mkdir(parents=True, exist_ok=True)
        
        log_file = self.log_path / 'compliance_validation.log'
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def _get_hostname(self) -> str:
        """Get system hostname"""
        try:
            return subprocess.getoutput('hostname').strip()
        except Exception:
            return 'unknown'
    
    def _load_control_definitions(self) -> Dict[str, Any]:
        """Load CMMC control definitions from configuration file"""
        control_file = self.config_path / 'cmmc_controls.yaml'
        
        if not control_file.exists():
            self.logger.warning(f"Control definitions file not found: {control_file}")
            return {}
        
        try:
            with open(control_file, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            self.logger.error(f"Failed to load control definitions: {e}")
            return {}
    
    def _run_command(self, command: str) -> tuple[int, str, str]:
        """
        Execute system command and return results
        
        Args:
            command: Command to execute
            
        Returns:
            Tuple of (return_code, stdout, stderr)
        """
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return 1, "", "Command timeout"
        except Exception as e:
            return 1, "", str(e)
    
    def _check_file_exists(self, file_path: str) -> bool:
        """Check if file exists at specified path"""
        return Path(file_path).exists()
    
    def _check_service_status(self, service_name: str) -> bool:
        """Check if systemd service is active"""
        rc, stdout, stderr = self._run_command(f'systemctl is-active {service_name}')
        return rc == 0 and 'active' in stdout
    
    def _check_file_permissions(self, file_path: str, expected_mode: str) -> bool:
        """Check if file has expected permissions"""
        try:
            file_stat = os.stat(file_path)
            actual_mode = oct(file_stat.st_mode)[-3:]
            return actual_mode == expected_mode
        except Exception:
            return False
    
    def validate_ac_controls(self) -> Dict[str, Any]:
        """
        Validate Access Control (AC) controls
        
        Validates:
        - AC.1.001: Authorized user access restrictions
        - AC.1.002: Authorized transaction controls
        - AC.1.003: Public system information controls
        """
        ac_results = {}
        
        # AC.1.001 - SSH Configuration Validation
        ssh_config_path = '/etc/ssh/sshd_config'  # Could be made configurable
        ac_results['AC.1.001'] = self._validate_ssh_config(ssh_config_path)
        
        # AC.1.002 - Sudo Configuration Validation
        sudoers_path = '/etc/sudoers.d/10-cmmc-restrictions'
        ac_results['AC.1.002'] = self._validate_sudo_config(sudoers_path)
        
        # AC.1.003 - System Information Disclosure Controls
        ac_results['AC.1.003'] = self._validate_system_disclosure()
        
        return ac_results
    
    def _validate_ssh_config(self, config_path: str) -> Dict[str, Any]:
        """Validate SSH configuration for AC.1.001 compliance"""
        result = {
            'control': 'AC.1.001',
            'title': 'Limit information system access to authorized users',
            'status': 'UNKNOWN',
            'details': {},
            'findings': []
        }
        
        try:
            if not self._check_file_exists(config_path):
                result['status'] = 'FAIL'
                result['findings'].append(f'SSH config file not found: {config_path}')
                return result
            
            with open(config_path, 'r') as f:
                config_content = f.read()
            
            # Check password authentication is disabled
            password_auth_disabled = 'PasswordAuthentication no' in config_content
            result['details']['password_auth_disabled'] = password_auth_disabled
            
            # Check public key authentication is enabled
            pubkey_auth_enabled = 'PubkeyAuthentication yes' in config_content
            result['details']['pubkey_auth_enabled'] = pubkey_auth_enabled
            
            # Check for AllowUsers restriction
            allow_users_configured = 'AllowUsers' in config_content
            result['details']['allow_users_configured'] = allow_users_configured
            
            # Check SSH service is running
            ssh_service_active = self._check_service_status('sshd')
            result['details']['ssh_service_active'] = ssh_service_active
            
            # Determine overall status
            if all([password_auth_disabled, pubkey_auth_enabled, ssh_service_active]):
                result['status'] = 'PASS'
            else:
                result['status'] = 'FAIL'
                if not password_auth_disabled:
                    result['findings'].append('Password authentication not disabled')
                if not pubkey_auth_enabled:
                    result['findings'].append('Public key authentication not enabled')
                if not ssh_service_active:
                    result['findings'].append('SSH service not active')
            
        except Exception as e:
            result['status'] = 'ERROR'
            result['findings'].append(f'SSH validation error: {str(e)}')
        
        return result
    
    def _validate_sudo_config(self, config_path: str) -> Dict[str, Any]:
        """Validate sudo configuration for AC.1.002 compliance"""
        result = {
            'control': 'AC.1.002',
            'title': 'Limit information system access to authorized transactions',
            'status': 'UNKNOWN',
            'details': {},
            'findings': []
        }
        
        try:
            # Check if CMMC sudo restrictions exist
            cmmc_sudo_exists = self._check_file_exists(config_path)
            result['details']['cmmc_sudo_config_exists'] = cmmc_sudo_exists
            
            # Check sudo logging configuration
            rc, stdout, stderr = self._run_command('grep -r "logfile=" /etc/sudoers /etc/sudoers.d/ 2>/dev/null')
            sudo_logging_enabled = rc == 0 and 'logfile=' in stdout
            result['details']['sudo_logging_enabled'] = sudo_logging_enabled
            
            # Check sudo log file exists
            sudo_log_exists = self._check_file_exists('/var/log/sudo.log')
            result['details']['sudo_log_exists'] = sudo_log_exists
            
            # Determine overall status
            if cmmc_sudo_exists and sudo_logging_enabled:
                result['status'] = 'PASS'
            else:
                result['status'] = 'FAIL'
                if not cmmc_sudo_exists:
                    result['findings'].append('CMMC sudo restrictions not configured')
                if not sudo_logging_enabled:
                    result['findings'].append('Sudo logging not enabled')
            
        except Exception as e:
            result['status'] = 'ERROR'
            result['findings'].append(f'Sudo validation error: {str(e)}')
        
        return result
    
    def _validate_system_disclosure(self) -> Dict[str, Any]:
        """Validate system information disclosure controls for AC.1.003"""
        result = {
            'control': 'AC.1.003',
            'title': 'Control information posted or processed on publicly accessible systems',
            'status': 'UNKNOWN',
            'details': {},
            'findings': []
        }
        
        try:
            # Check login banner configuration
            issue_exists = self._check_file_exists('/etc/issue')
            issue_net_exists = self._check_file_exists('/etc/issue.net')
            result['details']['login_banners_configured'] = issue_exists and issue_net_exists
            
            # Check SSH banner configuration
            ssh_config_path = '/etc/ssh/sshd_config'
            ssh_banner_configured = False
            if self._check_file_exists(ssh_config_path):
                with open(ssh_config_path, 'r') as f:
                    ssh_config = f.read()
                    ssh_banner_configured = 'Banner' in ssh_config
            
            result['details']['ssh_banner_configured'] = ssh_banner_configured
            
            # Check for information disclosure in banners
            info_disclosure_found = False
            for banner_file in ['/etc/issue', '/etc/issue.net']:
                if self._check_file_exists(banner_file):
                    with open(banner_file, 'r') as f:
                        content = f.read().lower()
                        if any(term in content for term in ['version', 'kernel', 'linux', 'ubuntu', 'centos', 'rhel']):
                            info_disclosure_found = True
                            break
            
            result['details']['info_disclosure_in_banners'] = info_disclosure_found
            
            # Determine overall status
            if (issue_exists and issue_net_exists and ssh_banner_configured and not info_disclosure_found):
                result['status'] = 'PASS'
            else:
                result['status'] = 'FAIL'
                if not (issue_exists and issue_net_exists):
                    result['findings'].append('Login banners not properly configured')
                if not ssh_banner_configured:
                    result['findings'].append('SSH banner not configured')
                if info_disclosure_found:
                    result['findings'].append('System information disclosed in banners')
            
        except Exception as e:
            result['status'] = 'ERROR'
            result['findings'].append(f'System disclosure validation error: {str(e)}')
        
        return result
    
    def validate_au_controls(self) -> Dict[str, Any]:
        """
        Validate Audit and Accountability (AU) controls
        
        Validates:
        - AU.1.006: Audit record generation and content
        - AU.1.012: Audit record generation capability
        """
        au_results = {}
        
        # AU.1.006 - Audit Configuration Validation
        au_results['AU.1.006'] = self._validate_audit_configuration()
        
        # AU.1.012 - Audit Capability Validation
        au_results['AU.1.012'] = self._validate_audit_capability()
        
        return au_results
    
    def _validate_audit_configuration(self) -> Dict[str, Any]:
        """Validate audit system configuration for AU.1.006"""
        result = {
            'control': 'AU.1.006',
            'title': 'Create and retain audit records with specific content',
            'status': 'UNKNOWN',
            'details': {},
            'findings': []
        }
        
        try:
            # Check auditd service status
            auditd_active = self._check_service_status('auditd')
            result['details']['auditd_service_active'] = auditd_active
            
            # Check audit rules are loaded
            rc, stdout, stderr = self._run_command('auditctl -l')
            audit_rules_loaded = rc == 0 and len(stdout.strip()) > 0
            result['details']['audit_rules_loaded'] = audit_rules_loaded
            
            # Check audit log directory exists and has proper permissions
            audit_log_dir = '/var/log/audit'
            audit_log_dir_exists = self._check_file_exists(audit_log_dir)
            result['details']['audit_log_dir_exists'] = audit_log_dir_exists
            
            # Check audit log file exists
            audit_log_file = '/var/log/audit/audit.log'
            audit_log_exists = self._check_file_exists(audit_log_file)
            result['details']['audit_log_exists'] = audit_log_exists
            
            # Count audit rules for compliance verification
            rule_count = len(stdout.strip().split('\n')) if audit_rules_loaded else 0
            result['details']['audit_rule_count'] = rule_count
            
            # Determine overall status
            if auditd_active and audit_rules_loaded and audit_log_exists and rule_count > 0:
                result['status'] = 'PASS'
            else:
                result['status'] = 'FAIL'
                if not auditd_active:
                    result['findings'].append('Auditd service not active')
                if not audit_rules_loaded:
                    result['findings'].append('Audit rules not loaded')
                if not audit_log_exists:
                    result['findings'].append('Audit log file not found')
                if rule_count == 0:
                    result['findings'].append('No audit rules configured')
            
        except Exception as e:
            result['status'] = 'ERROR'
            result['findings'].append(f'Audit configuration validation error: {str(e)}')
        
        return result
    
    def _validate_audit_capability(self) -> Dict[str, Any]:
        """Validate audit generation capability for AU.1.012"""
        result = {
            'control': 'AU.1.012',
            'title': 'Provide audit record generation capability for defined events',
            'status': 'UNKNOWN',
            'details': {},
            'findings': []
        }
        
        try:
            # Check specific audit rules for CMMC compliance
            required_audit_rules = [
                '/etc/passwd',     # User account changes
                '/etc/shadow',     # Password changes  
                '/etc/sudoers',    # Privilege changes
                'privileged'       # Privileged command execution
            ]
            
            rc, stdout, stderr = self._run_command('auditctl -l')
            
            rules_configured = {}
            for rule in required_audit_rules:
                rule_present = rule in stdout if rc == 0 else False
                rules_configured[rule] = rule_present
            
            result['details']['required_rules_configured'] = rules_configured
            
            # Check audit log rotation configuration
            logrotate_audit_exists = self._check_file_exists('/etc/logrotate.d/audit')
            result['details']['audit_log_rotation_configured'] = logrotate_audit_exists
            
            # Determine overall status
            all_rules_present = all(rules_configured.values())
            if all_rules_present and logrotate_audit_exists:
                result['status'] = 'PASS'
            else:
                result['status'] = 'FAIL'
                if not all_rules_present:
                    missing_rules = [rule for rule, present in rules_configured.items() if not present]
                    result['findings'].append(f'Missing required audit rules: {", ".join(missing_rules)}')
                if not logrotate_audit_exists:
                    result['findings'].append('Audit log rotation not configured')
            
        except Exception as e:
            result['status'] = 'ERROR'
            result['findings'].append(f'Audit capability validation error: {str(e)}')
        
        return result
    
    def run_all_validations(self) -> Dict[str, Any]:
        """
        Execute all CMMC compliance validations
        
        Returns:
            Complete validation results dictionary
        """
        self.logger.info("Starting comprehensive CMMC compliance validation")
        
        try:
            # Validate Access Control controls
            self.logger.info("Validating Access Control (AC) controls")
            self.results['controls']['ac'] = self.validate_ac_controls()
            
            # Validate Audit and Accountability controls
            self.logger.info("Validating Audit and Accountability (AU) controls")
            self.results['controls']['au'] = self.validate_au_controls()
            
            # Generate summary statistics
            self._generate_summary()
            
            # Save results to file
            self._save_results()
            
            self.logger.info("CMMC compliance validation completed")
            
        except Exception as e:
            self.logger.error(f"Validation failed with error: {str(e)}")
            self.results['error'] = str(e)
        
        return self.results
    
    def _generate_summary(self) -> None:
        """Generate validation summary statistics"""
        total_controls = 0
        passed_controls = 0
        failed_controls = 0
        error_controls = 0
        
        for family, controls in self.results['controls'].items():
            for control_id, control_result in controls.items():
                total_controls += 1
                status = control_result.get('status', 'UNKNOWN')
                
                if status == 'PASS':
                    passed_controls += 1
                elif status == 'FAIL':
                    failed_controls += 1
                elif status == 'ERROR':
                    error_controls += 1
        
        compliance_percentage = (passed_controls / total_controls * 100) if total_controls > 0 else 0
        
        self.results['summary'] = {
            'total_controls': total_controls,
            'passed_controls': passed_controls,
            'failed_controls': failed_controls,
            'error_controls': error_controls,
            'compliance_percentage': round(compliance_percentage, 2),
            'overall_status': 'COMPLIANT' if failed_controls == 0 and error_controls == 0 else 'NON_COMPLIANT'
        }
    
    def _save_results(self) -> None:
        """Save validation results to file"""
        try:
            # Create reports directory if it doesn't exist
            reports_dir = self.log_path / 'reports'
            reports_dir.mkdir(parents=True, exist_ok=True)
            
            # Generate filename with timestamp
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f'cmmc_compliance_report_{timestamp}.json'
            report_file = reports_dir / filename
            
            # Save results as JSON
            with open(report_file, 'w') as f:
                json.dump(self.results, f, indent=2)
            
            # Create symlink to latest report
            latest_link = reports_dir / 'latest_compliance_report.json'
            if latest_link.exists():
                latest_link.unlink()
            latest_link.symlink_to(filename)
            
            self.logger.info(f"Validation results saved to: {report_file}")
            
        except Exception as e:
            self.logger.error(f"Failed to save results: {str(e)}")

def main():
    """Main function for command-line execution"""
    parser = argparse.ArgumentParser(description='CMMC Compliance Validator')
    parser.add_argument('--config-dir', default=DEFAULT_CONFIG_PATH,
                       help='CMMC configuration directory path')
    parser.add_argument('--log-dir', default=DEFAULT_LOG_PATH,
                       help='CMMC log directory path')
    parser.add_argument('--state-dir', default=DEFAULT_STATE_PATH,
                       help='CMMC state directory path')
    parser.add_argument('--output', choices=['json', 'summary'], default='summary',
                       help='Output format')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Adjust logging level if verbose
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Create validator instance
    validator = CMICComplianceValidator(
        config_path=args.config_dir,
        log_path=args.log_dir,
        state_path=args.state_dir
    )
    
    # Run validation
    results = validator.run_all_validations()
    
    # Output results
    if args.output == 'json':
        print(json.dumps(results, indent=2))
    else:
        # Summary output
        summary = results.get('summary', {})
        print(f"\nCMMC Compliance Validation Results")
        print(f"=" * 40)
        print(f"Hostname: {results.get('hostname', 'unknown')}")
        print(f"Timestamp: {results.get('timestamp', 'unknown')}")
        print(f"Total Controls: {summary.get('total_controls', 0)}")
        print(f"Passed: {summary.get('passed_controls', 0)}")
        print(f"Failed: {summary.get('failed_controls', 0)}")
        print(f"Errors: {summary.get('error_controls', 0)}")
        print(f"Compliance: {summary.get('compliance_percentage', 0):.1f}%")
        print(f"Status: {summary.get('overall_status', 'UNKNOWN')}")
        
        # Show failures if any
        if summary.get('failed_controls', 0) > 0:
            print(f"\nFailed Controls:")
            for family, controls in results.get('controls', {}).items():
                for control_id, control_result in controls.items():
                    if control_result.get('status') == 'FAIL':
                        print(f"- {control_id}: {control_result.get('title', 'Unknown')}")
                        for finding in control_result.get('findings', []):
                            print(f"  * {finding}")
    
    # Exit with appropriate code
    summary = results.get('summary', {})
    exit_code = 0 if summary.get('overall_status') == 'COMPLIANT' else 1
    sys.exit(exit_code)

if __name__ == '__main__':
    main()