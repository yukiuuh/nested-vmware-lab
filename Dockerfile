FROM python:3.11.9-slim-bookworm

ARG USERNAME=bootstrap
ARG USER_UID=999
ARG USER_GID=$USER_UID

COPY --from=hashicorp/terraform /bin/terraform /bin/terraform
COPY --from=vmware/govc /govc /bin/govc
COPY --from=hairyhenderson/gomplate /gomplate /bin/gomplate

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    apt-get update && \
    apt-get install -y vim ssh sshpass netcat-openbsd git ca-certificates --no-install-recommends && \
    pip install pip --upgrade && \
    pip install --no-cache-dir ansible==10.0.0a1 ansible-lint pyvmomi jmespath passlib netaddr git+https://github.com/vmware/vsphere-automation-sdk-python.git && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /app/workspace && \
    chown -R ${USER_UID}:${USER_GID} /app
USER ${USERNAME}
RUN ansible-galaxy collection install community.general && \
    ansible-galaxy collection install community.vmware && \
    ansible-galaxy collection install ansible.utils && \
    ansible-galaxy collection install vmware.alb && \
    ansible-galaxy collection install git+https://github.com/vmware/ansible-for-nsxt

RUN pip install -r ~/.ansible/collections/ansible_collections/vmware/alb/requirements.txt

COPY --chown=${USER_UID}:${USER_GID} ./deployments /app/deployments
COPY --chown=${USER_UID}:${USER_GID} ./module /app/module
COPY --chown=${USER_UID}:${USER_GID} ./playbooks /app/playbooks
COPY --chown=${USER_UID}:${USER_GID} ./scripts/* /bin/
COPY --chown=${USER_UID}:${USER_GID} ./templates /app/templates
COPY --chown=${USER_UID}:${USER_GID} ./examples /app/examples

RUN cd /app/deployments/nested_vsphere/ && terraform init -input=false

WORKDIR /app

ENTRYPOINT [ "/bin/bash" ]