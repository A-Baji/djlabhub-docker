#!/bin/sh
run_post_start_jobs() {
    # remove files and hidden files
    rm -R /home/tutorial/*
    rm -rf /home/tutorial/.* 2> /dev/null
    #clone
    git clone $NB_REPO /home/tutorial
    # copy global config
    if [ ! -z "${DJ_PASS}" ]; then
        #password available
        cp /usr/local/bin/.datajoint_config.json ~/
        sed -i "s|\"database.host\": null|\"database.host\": \"${DJ_HOST}\"|g" ~/.datajoint_config.json
        sed -i "s|\"database.user\": null|\"database.user\": \"${DJ_USER}\"|g" ~/.datajoint_config.json
        sed -i "s|\"database.password\": null|\"database.password\": \"${DJ_PASS}\"|g" ~/.datajoint_config.json
    elif [ -z "${DJ_PASS}" ] && [ ! -f "~/.datajoint_config.json" ]; then
        #empty var but no initial config
        rm ~/../common/.${NB_ENV}_datajoint_config.json || echo "No ${NB_ENV} datajoint config backup detected"
        cp /usr/local/bin/.datajoint_config.json ~/
        sed -i "s|\"database.host\": null|\"database.host\": \"${DJ_HOST}\"|g" ~/.datajoint_config.json
        sed -i "s|\"database.user\": null|\"database.user\": \"${DJ_USER}\"|g" ~/.datajoint_config.json
        for i in ~/../common/.*datajoint_config.json; do
            if [ ! "$i" = "~/../common/.*datajoint_config.json" ] && [ "$(jq -r '.["database.host"]' $i)" = "$DJ_HOST" ] && [ "$(jq -r '.["database.user"]' $i)" = "$DJ_USER" ]; then
                sed -i "s|\"database.password\": null|\"database.password\": \""$(jq -r '.["database.password"]' $i)"\"|g" ~/.datajoint_config.json
                break
            fi
        done
    fi
    cp ~/.datajoint_config.json ~/../common/.${NB_ENV}_datajoint_config.json
    #start monitoring global config
    sh - <<EOF &
    inotifywait -m ~/.datajoint_config.json |
        while read path action file; do
            if [ "\$(echo \$action | grep MODIFY)" ] || [ "\$(echo \$action | grep CREATE)" ] || [ "\$(echo \$action | grep MOVE)" ]; then
                echo "DataJoint global config change detected. Backing up..."
                cp ~/.datajoint_config.json ~/../common/.${NB_ENV}_datajoint_config.json
            fi
        done
EOF
    #pip install requirements in root + pipeline
    if [ -f "/home/tutorial/requirements.txt" ]; then
        # pip install --user -r /home/tutorial/requirements.txt
        pip install -r /home/tutorial/requirements.txt --user --upgrade
    fi
    if [ -f "/home/tutorial/setup.py" ]; then
        pip install --user --upgrade /home/tutorial
    fi
    #copy subset
    mkdir /tmp/tutorial
    cp -R /home/tutorial/${NB_REPO_RELPATH}/* /tmp/tutorial
    cp -r /home/tutorial/${NB_REPO_RELPATH}/.[^.]* /tmp/tutorial
    #remove files and hidden files
    rm -R /home/tutorial/*
    rm -rf /home/tutorial/.* 2> /dev/null
    #move contents
    mv /tmp/tutorial/* /home/tutorial
    mv /tmp/tutorial/.[^.]* /home/tutorial
    #remove prev temp directory
    rm -R /tmp/tutorial
}

#Fix UID/GID
/startup -user=dja -new_uid=$(id -u) -new_gid=$(id -g) -new_user=${NB_USER}

#Enable conda paths
. /etc/profile.d/shell_intercept.sh

#Post start hook
run_post_start_jobs

#Install Python dependencies
if [ -f "$PIP_REQUIREMENTS" ]; then
    pip install --user -r $PIP_REQUIREMENTS
fi

#Install Conda dependencies
if [ -f "$CONDA_REQUIREMENTS" ]; then
    conda install -yc conda-forge --file $CONDA_REQUIREMENTS
fi

#Run command
cd ~
"$@"
