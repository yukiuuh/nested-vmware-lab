{
  description = "Nested VMware Lab development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        python = pkgs.python311;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "nested-vmware-lab";

          buildInputs = with pkgs; [
            # Python 3.11 (ansible-for-nsxt requires 3.11)
            python

            # Infrastructure tools
            terraform
            govc
            gomplate
            packer

            # Utilities
            yq-go
            openssh
            sshpass
            netcat-gnu
            git
            curl
            vim
            rclone
          ];

          shellHook = ''
            echo "🔧 Nested VMware Lab — Nix devshell"
            echo ""

            # Create/activate a venv for pip-managed Python packages
            VENV_DIR="''${PWD}/.venv"
            if [ ! -d "$VENV_DIR" ]; then
              echo "📦 Creating Python 3.11 venv..."
              python -m venv "$VENV_DIR"
            fi
            source "$VENV_DIR/bin/activate"

            # Install Python packages via pip (matching Dockerfile)
            if [ ! -f "$VENV_DIR/.installed" ]; then
              echo "📦 Installing Python packages..."
              pip install -q --upgrade pip
              pip install -q \
                ansible==10.0.0a1 \
                ansible-lint \
                pyvmomi \
                jmespath \
                passlib \
                netaddr \
                requests \
                git+https://github.com/vmware/vsphere-automation-sdk-python.git
              touch "$VENV_DIR/.installed"
            fi

            # Install Ansible collections if not present
            COLLECTIONS_DIR="$HOME/.ansible/collections/ansible_collections"

            install_collection() {
              local name="$1"
              local dir_name="''${name//.//}"
              if [ ! -d "$COLLECTIONS_DIR/$dir_name" ]; then
                echo "📦 Installing Ansible collection: $name"
                ansible-galaxy collection install "$name" --force
              fi
            }

            install_collection "community.general"
            install_collection "community.vmware"
            install_collection "ansible.utils"
            install_collection "vmware.alb"
            install_collection "vmware.vmware"

            # ansible-for-nsxt (from git)
            if [ ! -d "$COLLECTIONS_DIR/vmware/ansible_for_nsxt" ]; then
              echo "📦 Installing Ansible collection: vmware.ansible_for_nsxt (git)"
              ansible-galaxy collection install git+https://github.com/vmware/ansible-for-nsxt
            fi

            # Install Python deps for vmware.alb collection
            if [ -f "$COLLECTIONS_DIR/vmware/alb/requirements.txt" ]; then
              pip install -q -r "$COLLECTIONS_DIR/vmware/alb/requirements.txt" 2>/dev/null || true
            fi

            echo ""
            echo "Available tools:"
            echo "  python        $(python --version)"
            echo "  ansible       $(ansible --version | head -1)"
            echo "  govc          $(govc version 2>/dev/null || echo 'not found')"
            echo "  terraform     $(terraform version -json 2>/dev/null | yq -p json '.terraform_version' || echo 'not found')"
            echo "  packer        $(packer version 2>/dev/null || echo 'not found')"
            echo "  yq            $(yq --version 2>/dev/null || echo 'not found')"
            echo "  rclone        $(rclone version 2>/dev/null | head -1 || echo 'not found')"
            echo ""
          '';
        };
      }
    );
}
