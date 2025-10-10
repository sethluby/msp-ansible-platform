for file in ansible/playbooks/*.yml; do
    # Add --- if missing
    grep -q "^---" "$file" || sed -i '1i---' "$file"

    # Fix common indentation patterns
    sed -i '/^  pre_tasks:$/,/^  tasks:$/{
      s/^  - name:/    - name:/
      s/^    tags:/      tags:/
      s/^    - /        - /
    }' "$file"

  sed -i '/^  tasks:$/,/^  post_tasks:$/{
      s/^  - name:/    - name:/
      s/^    tags:/      tags:/
      s/^    - /        - /
    }' "$file"

    # Fix indentation within post_tasks
    sed -i '/^  post_tasks:$/,${
      s/^  - name:/    - name:/
      s/^    tags:/      tags:/
      s/^    - /        - /
    }' "$file"
  done
