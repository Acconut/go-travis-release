#!/bin/bash -e

# Test if we have an release commit
msg=$(git log --format=%B -n 1 $TRAVIS_COMMIT)
if [[ $msg == Release* ]] || [[ $msg == release* ]]
then
    echo "Found release commit"
else
    echo "No release commit found"
    exit 0
fi

# Get version from commit message
version=$(echo $msg | awk '{print $2}')
echo "Releasing ${version} ..."

data="{\
\"tag_name\":\"${version}\",\
\"target_commitish\":\"${TRAVIS_COMMIT}\",\
\"name\":\"${version}\",\
\"body\":\"Release ${version}\"\
}"

body=$(curl \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${OAUTH_TOKEN}:x-oauth-basic" \
    -d "$data" \
    https://api.github.com/repos/$TRAVIS_REPO_SLUG/releases)

# Get release id
release_id=$(echo $body | grep -oP "\"id\": \d+" | head -1 | awk '{print $2}')
echo "Created release ${release_id}"

# Get only repo name
repo=$(echo $TRAVIS_REPO_SLUG | cut -d"/" -f2)

function upload {
    local name=$1
    local content_type=$2

    code=0
    while [ $code -ne "200" ]
    do
        code=$(curl -s -o /dev/null -w "%{http_code}" -OL "http://gobuild3.qiniudn.com/github.com/${TRAVIS_REPO_SLUG}/tag-v-${version}/${repo}-${name}")
        echo "Requested ${repo}-${name}... ${code}"
        sleep 1
    done

    curl \
    -X POST \
    -u "${OAUTH_TOKEN}:x-oauth-basic" \
    -H "Content-Type: ${content_type}" \
    "https://uploads.github.com/repos/${TRAVIS_REPO_SLUG}/releases/${release_id}/assets?name=${name}" \
    -d "@${repo}-${name}"
    
}

# Start build
escaped_repo=$(echo $TRAVIS_REPO_SLUG | tr "/" "%2F2)
curl -i "http://gobuild.io/task/build?tag=tag%3A${version}&reponame=github.com%2F${escaped_repo}"

# Upload builds from gobuild.io
upload "windows-386.zip" "application/zip"
upload "windows-amd64.zip" "application/zip"
upload "linux-386.tar.gz", "application/gzip"
upload "linux-amd64.tar.gz", "application/gzip"
upload "linux-arm.tar.gz", "application/gzip"
upload "darwin-386.zip", "application/zip"
upload "darwin-amd64.zip", "application/zip"
