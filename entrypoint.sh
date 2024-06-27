#!/bin/bash

# Required inputs
GITHUB_PUSH_SECRET=$1
DOCKER_IMAGE_NAME=$2
DOCKER_IMAGE_TAG=latest
DOCKERFILE_PATH=$4
BUILD_CONTEXT=$5
BUILD_ONLY=$6
DOCKER_BUILD_ARGS=$7

# Initialize array to hold image directories
IMAGES_TO_MAKE=()

# Populate the array with directories
for dir in */; do
    IMAGES_TO_MAKE+=("$dir")
done

echo "Logging into GitHub Container Registry..."
# Log in to GitHub Container Registry
echo ${GITHUB_PUSH_SECRET} | docker login https://ghcr.io -u ${GITHUB_ACTOR} --password-stdin
if [ $? -ne 0 ]; then
    echo "Docker login failed"
    exit 1
fi
echo "Docker login successful"

# Extract GitHub owner from repository name
GITHUB_OWNER="$(echo ${GITHUB_REPOSITORY} | cut -d/ -f1)"

echo "Images to be built: ${IMAGES_TO_MAKE[@]}"

# Iterate over each directory to build and optionally push Docker images
for current_image in "${IMAGES_TO_MAKE[@]}"; do
    echo "Processing directory: ${current_image}"
    DOCKERFILE_PATH="${current_image}"
    # Normalize the image ID
    IMAGE_ID="$(echo ${current_image%/} | tr '[A-Z]' '[a-z]')"
    
    # Construct build context and image name
    BUILD_CONTEXT="Dockerfile-${current_image%/}"
    IMAGE_NAME=ghcr.io/${GITHUB_OWNER}/${IMAGE_ID}:${DOCKER_IMAGE_TAG}
    
    echo "Building Docker image: ${IMAGE_NAME} with build context: ${BUILD_CONTEXT} and Dockerfile: ${DOCKERFILE_PATH}"
    
    # Process build arguments
    IFS=',' read -a items <<< "$DOCKER_BUILD_ARGS"
    BUILD_ARGS=''
    for element in "${items[@]}"; do
        if [ "$element" ]; then
            BUILD_ARGS="$BUILD_ARGS --build-arg $element"
        fi
    done
    
    echo "Build arguments: ${BUILD_ARGS}"
    
    # Build the Docker image
    docker build ${BUILD_CONTEXT} -t ${IMAGE_NAME} -f ${DOCKERFILE_PATH} ${BUILD_ARGS}
    if [ $? -ne 0 ]; then
        echo "Docker build failed for ${IMAGE_NAME}"
        exit 1
    fi
    
    echo "Docker image ${IMAGE_NAME} built successfully"
    
    # Push the Docker image unless BUILD_ONLY is true
    if [ "$BUILD_ONLY" == "true" ]; then
        echo "Skipping push for ${IMAGE_NAME}"
    else
        echo "Pushing Docker image: ${IMAGE_NAME}"
        docker push ${IMAGE_NAME}
        if [ $? -ne 0 ]; then
            echo "Docker push failed for ${IMAGE_NAME}"
            exit 1
        fi
        echo "Docker image ${IMAGE_NAME} pushed successfully"
    fi
done
