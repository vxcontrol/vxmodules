#!/bin/bash

export LANG=C.UTF-8

DUMP_SQL_FILE=$( [ ! -z "$1" ] && echo "$1" || echo "dump.sql" )
CONFIG_MODULES="config.json"

get_modules_list() {
    jq -c ".[].name" -r $CONFIG_MODULES
}

get_module_version() {
    jq ".[] | select(.name == \"$1\") | .version" -r $CONFIG_MODULES
}

get_module_file_config() {
    jq "." -c "$1/$2" | sed 's/\\/\\\\/g'
}

echo > $DUMP_SQL_FILE

module_number=0
for module_name in $( get_modules_list ); do
    module_number=$((module_number+1))
    echo "Module number: $module_number"
    echo "Module name: $module_name"
    module_version=$( get_module_version $module_name )
    echo "Module version: $module_version"
    config_path="$module_name/$module_version/config"
    echo "Module config path: $config_path"
    echo
    
    module_config_schema=$( get_module_file_config $config_path "config_schema.json" )
    echo "Module config schema: $module_config_schema"
    echo
    
    module_default_config=$( get_module_file_config $config_path "default_config.json" )
    echo "Module default config: $module_default_config"
    echo
    
    module_event_data_schema=$( get_module_file_config $config_path "event_data_schema.json" )
    echo "Module event data schema: $module_event_data_schema"
    echo
    
    module_event_config_schema=$( get_module_file_config $config_path "event_config_schema.json" )
    echo "Module event config schema: $module_event_config_schema"
    echo
    
    module_default_event_config=$( get_module_file_config $config_path "default_event_config.json" )
    echo "Module default event config: $module_default_event_config"
    echo
    
    module_locale=$( get_module_file_config $config_path "locale.json" )
    echo "Module locale: $module_locale"
    echo
    
    module_changelog=$( get_module_file_config $config_path "changelog.json" )
    echo "Module changelog: $module_changelog"
    echo
    
    module_info=$( get_module_file_config $config_path "info.json" )
    echo "Module info: $module_info"
    echo

    echo "--  MODULE $module_name version $module_version--" >> $DUMP_SQL_FILE
    echo "INSERT IGNORE INTO \`modules\` (\`id\`, \`tenant_id\`, \`service_type\`, \`config_schema\`, \`default_config\`, \`event_data_schema\`,"\
        " \`event_config_schema\`, \`default_event_config\`, \`changelog\`, \`locale\`, \`info\`, \`last_update\`) "\
        "VALUES ($module_number, 0, 'vxmonitor', '{}', '{}', '{}', '{}', '{}', '{}', '{}', '{}', NOW());" >> $DUMP_SQL_FILE

    cat >> $DUMP_SQL_FILE <<- EOM
UPDATE \`modules\` SET \`last_update\`=NOW(),
    \`config_schema\`='$module_config_schema',
    \`default_config\`='$module_default_config',
    \`event_data_schema\`='$module_event_data_schema',
    \`event_config_schema\`='$module_event_config_schema',
    \`default_event_config\`='$module_default_event_config',
    \`locale\`='$module_locale',
    \`changelog\`='$module_changelog',
    \`info\`='$module_info'
WHERE \`id\`=$module_number;
EOM
    echo >> $DUMP_SQL_FILE
done
