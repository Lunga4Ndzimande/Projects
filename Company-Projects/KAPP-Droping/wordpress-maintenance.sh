#!/usr/bin/env bash
clear

# colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

# reset parameters
ticket_number=""
s3_backup_URI=""
source_URL=""
destination_URL=""

# print filename and option used to execute to screen
echo ========================================================================================
echo ${0} ${@}


fn_log_to_file () {
        #logging
        # method to log to log file
        # | tee -a ${logfile}
        #script --append $logfile
        #exec 19>$logfile
        #BASH_XTRACEFD=19
        set -x
        #logfile=$work_folder"/"$timestamp".log"
        #exec &> $logfile
        }

# todo
# append all commands to log file in the work directory for debugging
# send some notifications to slack for visibility?
# make sure there is enough disk space before starting
# move the order of execution around since the mysqldump has high probability of failing it should likely be first.
# dump cat parameter is not printing correct
# add more logic to the sed portions when the sed does not complete  && echo "success" || echo "failure"; exit 0 --- can we confirm/print the occurances of the seds to console
# adapt the fn_download_s3 to accept local/storage file paths as well
# accept multiple database for backup functions (with retry and timeouts) so we can use this as the normal backup script
# analyze and optimze should be built in here as well
# add explanation or rather a readme.md to source control explaning the use.
# change backups to hapen against the read replica

fn_usage() {
        echo "usage: ${0} [option]"
        echo "$(basename $0) restore_local     Performs a restore on the same environment between databases "
        echo "$(basename $0) restore_remote    Performs a restore from S3 "
        echo "$(basename $0) backup_remote     Performs a backup locally and the copies it to S3 "
        }


fn_global_prep () {
        . /backups/DBA/env.sh # read the environmental variables
        timestamp=`date +"%Y%m%d_%H%M%S"`
        work_folder="/backups/$ticket_number"
        mkdir -p $work_folder
        cd $work_folder
        }


fn_download_s3 () {
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Downloading and preparing backup"
        s3_archivename=$timestamp"_"$source_database"_s3.sql.gz"
        echo "${green}-- Downloading file from s3""${reset}"
        aws s3 cp $s3_backup_URI $work_folder'/'$s3_archivename
        extracted_filename=`gunzip -l $s3_archivename | awk '{print $4}' |  tail -n 1`
        echo "${green}-- Extracting gzip""${reset}"
        gunzip -k $work_folder"/"$s3_archivename
        echo "${green}""-- File extracted to [$work_folder/$extracted_filename]""${reset}"
        download_ouput=$extracted_filename
        echo ""
        }


fn_sed_replace () {
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Performing text substitutions"
        sed_filename="${sed_input/.sql/}_sed.sql"

        # database string
        echo "${green}""-- Changing text [$source_database] to [$destination_database]""${reset}"
        sed "s/$source_database/$destination_database/g;" $sed_input > $sed_filename

        # client string
        if [ $source_client != $destination_client ]
                then
                echo "${green}""-- Changing text [$source_client] to [$destination_client]""${reset}"
                sed -i "s/$source_client/$destination_client/g;" $sed_filename
                else
                echo "${green}""-- Client environments are the same, no need to replace""${reset}"
                fi

        # kurtosys environment
        if [ $source_kurtosys_environment != $destination_kurtosys_environment ]
                then
                echo "${green}""-- Changing text [$source_kurtosys_environment] to [$destination_kurtosys_environment]""${reset}"
                sed -i "s/$source_kurtosys_environment/$destination_kurtosys_environment/g;" $sed_filename
                else
                echo "${green}""-- Kurtosys environments are the same, no need to replace""${reset}"
                fi

        sed_output=$sed_filename
        echo ""
        }


fn_database_backup () {
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Performing backup of [$backup_input]"
        backup_filename=$timestamp"_"$backup_input"_backup.sql"
        mysqldump --set-gtid-purged=OFF --max_allowed_packet=512M  --hex-blob -h$WP_DB_READONLY_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD $backup_input > $backup_filename
        # checking to see if dump completed successfully
        successful_dump="$(tail -1 $backup_filename | grep "Dump completed on")"
        if [ -z "$successful_dump" ]
                then
                # failed
                echo "${yellow}""-- MySQLDump could not be confirmed""${reset}"
                echo "${yellow}""-- To view the log [cat $logfile]""${reset}"
                exit 0
                else
                # successful
                echo "${green}""$successful_dump""${reset}"
                #read -n 1 -r -p "${green}""-- Press any key to continue""${reset}"
                fi
        backup_output=$backup_filename
        echo ""
        }

fn_setting_backup_to_file () {
 echo `date +"%Y-%m-%d %H:%M:%S"` - "Performing backup of client settings [$backup_input]"
client_settings_filename=$timestamp"_"$backup_input"_settings_backup.sql"
mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD $destination_database -Ne "SELECT CONCAT(
        'INSERT INTO _wpoptions (option_name, option_value, autoload) ',
            'VALUES (',
            '''', option_name, ''', ',
            '''', option_value, ''', ',
            '''', autoload, ''') ON DUPLICATE KEY UPDATE  option_name = ''', option_name, '''',  ,  option_value = ''', option_value, ''',   autoload = ''', autoload, ''';')
        FROM _wpoptions
        WHERE option_name IN (
            'fvm-last-cache-update',
            'elementor_pro_license_key',
            'onelogin_saml_idp_sso',
            'onelogin_saml_idp_entityid',
            'home',
            'blogname',
            'siteurl');" > $client_settings_filename



     if [ "$?" -eq 0 ];
        then
        echo "${green}""-- Client Settings successfully Backed up ""${reset}"
        else
        echo "${red}""-- Failed to Save Client Settings ""${reset}"
        exit 0
        fi
        echo ""
}



fn_old_database_rename () {
echo `date +"%Y-%m-%d %H:%M:%S"` - "Performing Rename of Current DB [$backup_input] to [$backup_input'_old']"
rename_old_database_filename=$timestamp"_"$backup_input"_old_database_rename.sql"

mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD -e "DROP SCHEMA IF EXISTS $destination_database_old; CREATE DATABASE $destination_database_old;"
mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD "$destination_database" -Ne "SELECT CONCAT('RENAME TABLE ',table_schema,'.',table_name,
    ' TO ','$destination_database_old.',table_name,';')
FROM information_schema.TABLES
WHERE table_schema LIKE '$destination_database';" > $rename_old_database_filename

mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD $destination_database < $rename_old_database_filename
        if [ "$?" -eq 0 ];
        then
        echo "${green}""-- Database renamed successfully ""${reset}"
        else
        echo "${red}""-- Database renamed failed, for more information: [cat $logfile]""${reset}"
        exit 0
        fi
        echo ""


}

fn_temp_database_rename () {
echo `date +"%Y-%m-%d %H:%M:%S"` - "Performing Rename of [$backup_input'_temp'] DB to [$backup_input]"
rename_temp_database_filename=$timestamp"_"$backup_input"_temp_database_rename.sql"

mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD "$destination_database" -Ne "SELECT CONCAT('RENAME TABLE ',table_schema,'.',table_name,
    ' TO ','$destination_database.',table_name,';')
FROM information_schema.TABLES
WHERE table_schema LIKE '$destination_database_temp';" > $rename_temp_database_filename

mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD $destination_database < $rename_temp_database_filename
        if [ "$?" -eq 0 ];
        then
        echo "${green}""-- Database renamed successfully ""${reset}"
        else
        echo "${red}""-- Database renamed failed, for more information: [cat $logfile]""${reset}"
        exit 0
        fi
        echo ""


}

fn_database_restore_from_file () {
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Restoring [$source_database] to [$destination_database_temp] "
        read -n 1 -r -p "${green}""-- Press any key to continue...""${reset}"
        mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD -e "DROP SCHEMA IF EXISTS $destination_database_temp; CREATE DATABASE $destination_database_temp;"
        mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD $destination_database_temp < $restore_input
        if [ "$?" -eq 0 ];
        then
        echo "${green}""-- Database restored successfully""${reset}"
        else
        echo "${red}""-- The restore failed, for more information: [cat $logfile]""${reset}"
        exit 0
        fi
        echo ""
        }

fn_database_restore_settings_from_file () {
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Replacing settings in [$destination_database] with [$source_database]"
        mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD $destination_database_temp < $client_settings_filename
        if [ "$?" -eq 0 ];
        then
        echo "${green}""-- Client Settings restored successfully""${reset}"
        else
        echo "${red}""-- Client Settings Restore failed, for more information: [cat $logfile]""${reset}"
        exit 0
        fi
        echo ""
        }

        
fn_database_restore_cleanup () {
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Cleaning up after Restore[$destination_database] with [$source_database]"
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Dropping [$destination_database_temp]"
        mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD -e "DROP SCHEMA IF EXISTS $destination_database_temp;"
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Dropping [$destination_database_old]"
        mysql -h$WP_DB_HOST -u$WP_DB_USER -p$WP_DB_PASSWORD -e "DROP SCHEMA IF EXISTS $destination_database_old;"

        if [ "$?" -eq 0 ];
        then
        echo "${green}""-- Cleanup Successful""${reset}"
        else
        echo "${red}""-- Cleanup failed, for more information: [cat $logfile]""${reset}"
        exit 0
        fi
        echo ""
        }


fn_upload_s3 () {
        echo `date +"%Y-%m-%d %H:%M:%S"` - "Compress and upload to s3"
        pigz $upload_input
        if [ "$?" -eq 0 ];
        then
        echo "${green}""-- File compress successful""${reset}"
        else
        echo "${red}""-- Compress failed, for more information: [cat $logfile]""${reset}"
        exit 0
        fi
        compressed_filename=$upload_input".gz"
        s3_folder="s3://k-data-uk/Backups/WordPress/DXM_TEMP/$ticket_number"
        s3cmd put --quiet $compressed_filename $s3_folder"/"$compressed_filename
        #aws s3 cp $compressed_filename s3://k-data-uk/Backups/WordPress/DXM_TEMP/$compressed_filename
        if [ "$?" -eq 0 ];
        then
        echo "${green}""-- File successfully copied to [$s3_folder"/"$compressed_filename ]""${reset}"
        else
        echo "${red}""-- Copy failed, for more information: [cat $logfile]""${reset}"
        exit 0
        fi
        }

fn_input_parameters () {
        echo ========================================================================================
        echo "Before we start, we need some input parameters from you. Leave empty if not required. "
        echo
        read -p "What is your Jira ticket number?               [DATA-0000]                              " ticket_number
        read -p "What is your SOURCE URL?                       [https://blahblahblah-prd.ksysweb.com/]  " source_URL
        read -p "What is your DESTINATION client prefix?        [https://blahblahblah-dev.ksysweb.com/]  " destination_URL
        read -p "Generate S3 URI and past it here.              [s3://bucket.etc]                        " s3_backup_URI
        echo ========================================================================================
        echo

        # get SOURCE details
        source_client=`echo $source_URL | cut -d'/' -f3 | cut -d'.' -f1`
        source_database=${source_client//-/_}
        source_kurtosys_environment=`echo $source_URL | cut -d'/' -f3 | cut -d'.' -f2`".com"

        # get DESTINATION details
        destination_client=`echo $destination_URL | cut -d'/' -f3 | cut -d'.' -f1`
        destination_database=${destination_client//-/_}
        destination_kurtosys_environment=`echo $destination_URL | cut -d'/' -f3 | cut -d'.' -f2`".com"
        destination_database_temp=$destination_database"_temp"
        destination_database_old=$destination_database"_old"
        }


# ============================================================================================================
# execution logic
# ============================================================================================================
fn_restore_local () {

        fn_input_parameters
        fn_global_prep
        # backup source database
                backup_input=$source_database
                fn_database_backup                
        # find and replace text
                sed_input=$backup_output
                fn_sed_replace
        # backup destination before overwrite
                backup_input=$destination_database
                fn_database_backup
                fn_setting_backup_to_file
        # restore backed up database to tempdb
                restore_input=$sed_output
                fn_database_restore_from_file
                fn_database_restore_settings_from_file
        # Rename restored source database 
                restore_input=$sed_output
                fn_old_database_rename
                fn_temp_database_rename
                fn_database_restore_cleanup
        }


fn_restore_remote () {

        fn_input_parameters
        fn_global_prep
        # download the relevant file from s3
                fn_download_s3
        # find and replace text
                sed_input=$download_ouput
                fn_sed_replace
        # backup destination before overwrite
                backup_input=$destination_database
                fn_database_backup
                fn_setting_backup_to_file
        # restore downloaded database
                restore_input=$sed_output
                fn_database_restore_from_file
                fn_database_restore_settings_from_file
                fn_old_database_rename
                fn_temp_database_rename
                fn_database_restore_cleanup
        }


fn_backup_remote () {

        fn_input_parameters
        fn_global_prep
        # backup source database
                backup_input=$source_database
                fn_database_backup
        # upload to s3
                upload_input=$backup_filename
                fn_upload_s3
        }


if [ $# -eq 0 ]
        then
        fn_usage
        exit 1
        fi

case $1 in
         "restore_remote")
         fn_restore_remote
         ;;

         "restore_local")
         fn_restore_local
         ;;

         "backup_remote")
         fn_backup_remote
         ;;

         "help")
         fn_usage
         ;;
        *) echo "invalid option";;
        esac
