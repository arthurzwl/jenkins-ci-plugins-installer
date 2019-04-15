#!/bin/bash
set -e

DIR=$(cd "$(dirname "$0")"; pwd)
# modify JENKINS_HOME to change plugin install path
JENKINS_HOME=$DIR

if [ $# -eq 0 ]; then
  echo "USAGE: $0 filename"
  exit 1
fi
filename=$1

plugin_dir=$JENKINS_HOME/plugins
# file_owner=jenkins.jenkins

mkdir -p $plugin_dir

installPlugin() {
  if [ -f ${plugin_dir}/${1}.hpi -o -f ${plugin_dir}/${1}.jpi ]; then
    if [ "$2" == "1" ]; then
      return 1
    fi
    echo "Skipped: $1 (already installed)"
    return 0
  else
    echo "Installing: $1"
    # curl -L --silent --output ${plugin_dir}/${1}.hpi  https://updates.jenkins-ci.org/latest/${1}.hpi
    wget -q -O "${plugin_dir}/${1}.hpi" https://updates.jenkins-ci.org/latest/${1}.hpi
    return 0
  fi
}

while IFS= read -r line<&3;do
    installPlugin "$line"
done 3<$filename

changed=1
maxloops=100

while [ "$changed"  == "1" ]; do
  echo "Check for missing dependecies ..."
  if  [ $maxloops -lt 1 ] ; then
    echo "Max loop count reached - probably a bug in this script: $0"
    exit 1
  fi
  ((maxloops--))
  changed=0
  for f in ${plugin_dir}/*.hpi ; do
    # without optionals
    #deps=$( unzip -p ${f} META-INF/MANIFEST.MF | tr -d '\r' | sed -e ':a;N;$!ba;s/\n //g' | grep -e "^Plugin-Dependencies: " | awk '{ print $2 }' | tr ',' '\n' | grep -v "resolution:=optional" | awk -F ':' '{ print $1 }' | tr '\n' ' ' )
    # with optionals
    echo "check $f dependecies"
    deps=$( unzip -p ${f} META-INF/MANIFEST.MF | tr -d '\r' | sed -e ':a;N;$!ba;s/\n //g' | grep -e "^Plugin-Dependencies: " | awk '{ print $2 }' | tr ',' '\n' | awk -F ':' '{ print $1 }' | tr '\n' ' ' )
    for plugin in $deps; do
      installPlugin "$plugin" 1 && changed=1
    done
  done
done

echo "fixing permissions"

[ -z "$file_owner" ] ||
    chown ${file_owner} ${plugin_dir} -R

echo "all done"
