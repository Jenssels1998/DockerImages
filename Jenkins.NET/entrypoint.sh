#!/bin/bash

# Declare vars and set default values


# Start
echo "[$(date)] Setting up Jenkins.NET"
mkdir -p /tmp/jenkins_net

if [ $INSTALL_NETSDK = true ]; then
	# Add Microsoft package key
	echo "[$(date)] Adding Microsoft package key"
	wget https://packages.microsoft.com/config/ubuntu/21.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb >> /tmp/jenkins_net/wget_install.log
	dpkg -i packages-microsoft-prod.deb
	rm -v packages-microsoft-prod.deb
	echo "[$(date)] Added Microsoft package key"

	# Install .NET Sdk
	echo "[$(date)] Installing .NET Sdk packages"
	net_versions=($(echo $NETSDK_VERSIONS | tr "," "\n"))
	apt-get update -y >> /tmp/jenkins_net/apt_install.log
	for i in "${net_versions[@]}"
	do
		cmd="apt-get install -y dotnet-sdk-$i >> /tmp/jenkins_net/apt_install.log"
		eval "$cmd"
	done
	
	echo "[$(date)] Installed .NET Sdk packages"
fi

if [ $INSTALL_NUGET = true ]; then
	# Install NuGet
	echo "[$(date)] Installing NuGet"
	apt-get update -y && apt-get install -y nuget >> /tmp/jenkins_net/apt_install.log
	echo "[$(date)] Installed NuGet"
fi

if [ $INSTALL_DOCKER = true ]; then
	# Install Docker
	echo "[$(date)] Adding Docker repository"
	apt-get update -y && apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release >> /tmp/jenkins_net/apt_install.log
	curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
	echo "[$(date)] Added Docker repository"

	echo "[$(date)] Installing Docker"
	apt-get update -y && apt-get install -y docker-ce docker-ce-cli >> /tmp/jenkins_net/apt_install.log
	echo "[$(date)] Installed Docker"
	
	if [ $SET_MULTI_ARCH_BUILDER = true ]; then
		echo "[$(date)] Installing Qemu-User"
		apt-get update -y && apt-get install qemu-user -y >> /tmp/jenkins_net/apt_install.log
		echo "[$(date)] Installed Qemu-User"
		echo "[$(date)] Setting multi arch cpu builder as default for the docker buildx command"
		docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
		docker buildx rm multi-arch-builder
		docker buildx create --name multi-arch-builder --driver docker-container --node $MULTI_ARCH_BUILDER_NODE_NAME --use
		docker buildx inspect --bootstrap
		echo "[$(date)] Set multi-arch-builder as the default buildx builder"
	fi
fi

if [[ -n $EXTRA_PACKAGES ]]; then
	# Install Extra Packages
	echo "[$(date)] Installing extra packages"
	packages=($(echo $EXTRA_PACKAGES | tr "," "\n"))
	apt-get update -y >> /tmp/jenkins_net/apt_install.log
	for i in "${packages[@]}"
	do
		cmd="apt-get install -y $i >> /tmp/jenkins_net/apt_install.log"
		eval "$cmd"
	done
	
	echo "[$(date)] Installed extra packages"
fi

echo "[$(date)] Finished setting up Jenkins.NET. Calling jenkins entrypoint script"
/sbin/tini -- /usr/local/bin/jenkins.sh

exit