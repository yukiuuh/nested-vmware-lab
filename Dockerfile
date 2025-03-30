FROM python:3.11.9-slim-bookworm

ARG USERNAME=bootstrap
ARG USER_UID=1000
ARG USER_GID=$USER_UID

COPY --from=hashicorp/terraform /bin/terraform /bin/terraform
COPY --from=vmware/govc /govc /bin/govc

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    apt-get update && \
    apt-get install -y ssh sshpass netcat-openbsd git ca-certificates --no-install-recommends && \
    pip install pip --upgrade && \
    pip install --no-cache-dir ansible==10.0.0a1 ansible-lint pyvmomi jmespath passlib netaddr git+https://github.com/vmware/vsphere-automation-sdk-python.git && \
    rm -rf /var/lib/apt/lists/*

USER bootstrap
RUN ansible-galaxy collection install community.general && \
    ansible-galaxy collection install community.vmware && \
    ansible-galaxy collection install ansible.utils && \
    ansible-galaxy collection install git+https://github.com/vmware/ansible-for-nsxt

ENTRYPOINT [ "/bin/bash" ]