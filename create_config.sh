#!/bin/bash
set -x
cd $dir
export MDBCI_VM_PATH=$HOME/vms; mkdir -p $MDBCI_VM_PATH
~/mdbci/repository-config/generate_all.sh repo.d
# temporal solution - TODO: change 'product: maxscale version:' and add it to generate_all
~/mdbci/repository-config/maxscale-ci.sh $maxscale_target repo.d mariadb-maxscale

export repo_dir=$dir/repo.d/

echo "box: $box"
echo "template: $template"

provider=`$HOME/mdbci/mdbci show provider $box --silent 2> /dev/null`
template_raw="$HOME/mrm-jenkins/templates/template.$provider.json"
cp "$template_raw" template_tmp
eval "cat <<EOF
$(<template_tmp)
EOF" > "$MDBCI_VM_PATH/$name.json"

mkdir -p $MDBCI_VM_PATH/$name
cd $MDBCI_VM_PATH/$name
vagrant destroy -f
cd $dir

$HOME/mdbci/mdbci --override --template  $MDBCI_VM_PATH/$name.json --repo-dir $repo_dir generate $name

while [ -f ~/vagrant_lock ]
do
	echo "vagrant is locked, waiting ..."
	sleep 5
done
touch ~/vagrant_lock
echo $JOB_NAME-$BUILD_NUMBER >> ~/vagrant_lock

echo "running vagrant up $provider"

$HOME/mdbci/mdbci up $name --attempts 3
if [ $? != 0 ]; then
	echo "Error creating configuration"
	rm ~/vagrant_lock
	exit 1
fi

cp ~/build-scripts/team_keys .
$HOME/mdbci/mdbci public_keys --key team_keys $name

rm ~/vagrant_lock
