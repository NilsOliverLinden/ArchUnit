#!/bin/bash

set -e

if [[ ! $1 =~ ^[0-9]*\.[0-9]*\.[0-9]*(-[A-Z0-9]*)?$ ]]; then
    echo "You have to provide the old version as first parameter (without v-prefix, e.g. 0.14.0)"
    exit 1
fi

if [[ ! $2 =~ ^[0-9]*\.[0-9]*\.[0-9]*(-[A-Z0-9]*)?$ ]]; then
    echo "You have to provide the new version as second parameter (without v-prefix, e.g. 0.14.0)"
    exit 1
fi

OLD_VERSION=$1
NEW_VERSION=$2

if [[ $(git rev-parse --abbrev-ref HEAD) != "release-$NEW_VERSION" ]]; then
    echo "You are not on the release branch \"release-$NEW_VERSION\", aborting..."
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "There are local, uncommitted changes, aborting..."
    exit 1
fi

echo Old version is $OLD_VERSION. Releasing version $NEW_VERSION...

echo Updating version in build.gradle, README.md and docs...
sed -i -e s/version\ =.*/version\ =\ \'$NEW_VERSION\'/ build.gradle
sed -i -e s/$OLD_VERSION/$NEW_VERSION/ README.md ./docs/_data/navigation.yml ./docs/_pages/getting-started.md

echo Create release news...
./gradlew createReleaseNews

if [ -n "$(git status --porcelain)" ]; then
    echo Commiting version change
    git add build.gradle README.md ./docs -- ':!docs/**.png'
    git commit -m "Update version to $VERSION"
fi

echo Building and testing...
#./gradlew clean publishToMavenLocal runMavenTest -PallTests
./gradlew clean publishToMavenLocal

echo Publishing to Sonartype...
./gradlew publishToSonatype --no-parallel

echo Closing the repository...
./gradlew closeRepository

echo Check uploaded artifacts...
#./gradlew checkUploadedArtifacts

echo STAGING SUCCESSFUL!

releaseRepositoryAndPushVersion()
{
  echo Releasing the repository...
#  ./gradlew releaseRepository

  echo Pushing version and changes to GitHub repository...
  git push
  git reset --hard
}

updateWebpage()
{
  echo Updating webpage...
#  ./gradlew releaseArchUnit

  echo Pushing changes to GitHub repository...
#  git add ./build/*
#  git commit -m "Update webpage matching version $VERSION"
#  git push
}

echo $CI
if [[ $CI == "true" ]]
then
  releaseRepositoryAndPushVersion
  updateWebpage
else
  read -p "Do you want to release and push now? [y/N]" -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    releaseRepositoryAndPushVersion
    updateWebpage
  fi
fi
