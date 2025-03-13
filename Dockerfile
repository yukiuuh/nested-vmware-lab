FROM ubuntu:noble-20250127

COPY --from=hashicorp/terraform /bin/terraform /bin/terraform
COPY --from=vmware/govc /govc /bin/govc

RUN apt-get update && \
    apt-get install -y ssh sshpass netcat-openbsd git --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT [ "/bin/bash" ]