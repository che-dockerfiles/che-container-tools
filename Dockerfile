# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

FROM fedora:latest

# From: https://github.com/containers/buildah/blob/master/contrib/buildahimage/stable/Dockerfile
# buildah doesn't publish multi-arch images, so we need to replicate them here

# Don't include container-selinux and remove
# directories used by yum that are just taking
# up space.
RUN useradd build; yum -y update; yum -y reinstall shadow-utils; yum -y install buildah fuse-overlayfs --exclude container-selinux; rm -rf /var/cache /var/log/dnf* /var/log/yum.*;

ADD https://raw.githubusercontent.com/containers/buildah/master/contrib/buildahimage/stable/containers.conf /etc/containers/

# Adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf; sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' /etc/containers/storage.conf
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; touch /var/lib/shared/overlay-images/images.lock; touch /var/lib/shared/overlay-layers/layers.lock; touch /var/lib/shared/vfs-images/images.lock; touch /var/lib/shared/vfs-layers/layers.lock

# Set an environment variable to default to chroot isolation for RUN
# instructions and "buildah run".
ENV BUILDAH_ISOLATION=chroot


# Che steps: set up entrypoint, download deps

ENV KUBECTL_VERSION=v1.18.6
ENV HELM_VERSION=v3.2.4
ENV HOME=/home/theia
ENV TEKTONCD_VERSION=0.9.0

RUN mkdir /projects ${HOME} && \
    # Change permissions to let any arbitrary user
    for f in "${HOME}" "/etc/passwd" "/projects"; do \
      echo "Changing permissions on ${f}" && chgrp -R 0 ${f} && \
      chmod -R g+rwX ${f}; \
    done && \
    export ARCH="$(uname -m)" && if [[ ${ARCH} == "x86_64" ]]; then export ARCH_K8S_HELM="amd64"; elif [[ ${ARCH} == "aarch64" ]]; \
      then export ARCH_K8S_HELM="arm64"; elif [[ ${ARCH} == "s390x" ]]; then export ARCH_K8S_HELM="s390x"; elif [[ ${ARCH} == "ppc64le" ]]; \
      then export ARCH_K8S_HELM="ppc64le"; fi && \
    curl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/${ARCH_K8S_HELM}/kubectl -o /usr/local/bin/kubectl && \
    curl -o- -L https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH_K8S_HELM}.tar.gz | tar xvz -C /usr/local/bin --strip 1 && \
    export ARCH_TEKTON="$(uname -m)" && \
    echo $ARCH_TEKTON && \
    curl -LO https://github.com/tektoncd/cli/releases/download/v${TEKTONCD_VERSION}/tkn_${TEKTONCD_VERSION}_Linux_${ARCH_TEKTON}.tar.gz && \
    tar xvzf tkn_${TEKTONCD_VERSION}_Linux_${ARCH_TEKTON}.tar.gz -C /usr/local/bin/ tkn && \
    chmod +x /usr/local/bin/kubectl /usr/local/bin/helm /usr/local/bin/tkn

ADD etc/entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD ${PLUGIN_REMOTE_ENDPOINT_EXECUTABLE}
