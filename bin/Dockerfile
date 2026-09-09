FROM debian:bookworm-slim

ARG USER_NAME=developer
ARG USER_ID=1000
ARG GROUP_ID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        git \
        openssh-client \
        python3 \
        python3-pip \
        sudo \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if getent group "${GROUP_ID}" >/dev/null; then \
        user_group="$(getent group "${GROUP_ID}" | cut -d: -f1)"; \
    else \
        groupadd --gid "${GROUP_ID}" "${USER_NAME}"; \
        user_group="${USER_NAME}"; \
    fi; \
    if getent passwd "${USER_ID}" >/dev/null; then \
        existing_user="$(getent passwd "${USER_ID}" | cut -d: -f1)"; \
        usermod --login "${USER_NAME}" --home "/home/${USER_NAME}" \
            --move-home --shell /bin/bash --gid "${user_group}" "${existing_user}"; \
    else \
        useradd --uid "${USER_ID}" --gid "${user_group}" --create-home \
            --shell /bin/bash "${USER_NAME}"; \
    fi; \
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${USER_NAME}" \
        > "/etc/sudoers.d/${USER_NAME}"; \
    chmod 0440 "/etc/sudoers.d/${USER_NAME}"

ENV DEBIAN_FRONTEND=
USER ${USER_NAME}
WORKDIR /home/${USER_NAME}
CMD ["bash"]
