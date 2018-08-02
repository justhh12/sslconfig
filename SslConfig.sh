#!/bin/sh

# Version 1.0 - 31/07/2018
# Created by 

# This script will create and sign a new DA certificate to be used for enabling SSL for DA.

# GLOBAL VARIABLES
TMP_CERTS_HOME="/root"
DA_HOME="/opt/CA/DataAggregator"

#Colors
GEEN='\033[1;32m'     #  ${LGREEN}
BLUE='\033[0;34m'     #  ${BLUE}
LRED='\033[1;31m'     #  ${LRED}
NORMAL='\033[0m'      #  ${NORMAL}

STATUS="unknown"
HOME_DIRECTORY=`pwd`
HOSTNAME=`hostname`
KEY_PASS="QAisking"

function status_checks {

    # As user where DA was installed
    read -p "Where did you install DA [ Default = $DA_HOME ]:" DA_HOME
    DA_HOME=${DA_HOME:-/opt/CA/DataAggregator}
    # echo "DA_HOME is "$DA_HOME
    if [ ! -d "$DA_HOME" ]; then
        echo "'"$DA_HOME"' not found"
        exit
    fi
    
    APACHE_STATUS=`$DA_HOME/apache-karaf-2.4.3/bin/status`
    if [[ $APACHE_STATUS == R* ]] ; then
        COLOR='\033[0;32m'  # GREEN
    else
        COLOR='\033[0;31m'  # RED
    fi
    # First, figure out if SSL are already enabled or not
    SSL_STATUS=`netstat -ln | grep -E ':8581|8582' | awk '{print $4}' | grep -o '[0-9]*'`
    if [[ $SSL_STATUS =~ 8582 ]] ; then
        SSL_STATUS="ENABLED "
        SSL_REQUEST="disable"
    else
        SSL_STATUS="DISABLED"
        SSL_REQUEST="enable"
    fi
}

function setup {
    # Get random serial number (between 1000 and 9999)
    SERIAL=$[ ( $RANDOM % 999999 ) + 100000 ]

    #echo Serial Number is $SERIAL

    #echo "DA_HOME is "$DA_HOME
    if [ ! -d "$DA_HOME" ]; then
        echo "'"$DA_HOME"' not found"
        exit
    fi
    
    # Setup CACERTS_HOME 
    BASE_PATH=${DA_HOME//\/DataAggregator/}
    #echo "BASE_PATH is "$BASE_PATH
    CACERTS_HOME=${BASE_PATH}/jre/lib/security
#    echo "CACERTS_HOME is "$CACERTS_HOME
#    if [ ! -d "$CACERTS_HOME" ]; then
#        echo "'"$CACERTS_HOME"' not found"
#        exit
#    fi
 
    # Setup KEYTOOL 
    KEYTOOL=$DA_HOME/jre/bin/keytool
    #echo "KEYTOOL is "$KEYTOOL
    if [ ! -f "$KEYTOOL" ]; then
        echo "'"$KEYTOOL"' not found"
        exit
    fi 
    # Ask user where they would like to keep the temporary certificate files that will be created
    #read -p "Where would you like to place the temporary certificate files? [ Default = /root ]: " TMP_CERTS_HOME
    #TMP_CERTS_HOME=${TMP_CERTS_HOME:-/root}
    #echo TMP_CERTS_HOME is $TMP_CERTS_HOME

    # Update ca.cnf with new TMP_CERTS_HOME directory
    # sed -i "s/\$ROOT_HOME/\$TMP_CERTS_HOME/g" $TMP_CERTS_HOME/ca.cnf

    #echo Create necessary directories/files
    echo CA cert stuff will be located under $TMP_CERTS_HOME/mypersonalca temporarily.  Any files created under this directory will be removed after enabling or disabling SSL.
    cd $HOME_DIRECTORY
    mkdir $TMP_CERTS_HOME/mypersonalca
    cp -f ca.cnf openssl.cnf $TMP_CERTS_HOME/mypersonalca/
    cd $TMP_CERTS_HOME/mypersonalca
    sed -i "s/DNS.1 = <hostname>/DNS.1 = $HOSTNAME/" openssl.cnf
    mkdir certs
    mkdir private
    mkdir crl
    echo $SERIAL > serial
    touch index.txt

    # Stuff to workaround org uniqueness check
    read -p "What is your company name? [ Default = test_company ]:" ORG
    ORG=${ORG:-test_company}

    read -p "What is the name of your organization unit? [ Default = test_org_unit ]:" ORG_UNIT
    ORG_UNIT=${ORG_UNIT:-test_org_unit}

    read -p "What do you want to set for the certificate's Common Name? [ Default = test_common_name:" COMMON_NAME
    COMMON_NAME=${COMMON_NAME:-test_common_name}
    
    read -p "What is the two letter country code you would like to use? [ Default = XX ]:" COUNTRY
    COUNTRY=${COUNTRY:-XX}

    read -p "What is the name of your state or province? [ Default = test_state ]:" STATE
    STATE=${STATE:-test_state}
    
    read -p "What is the name of your locality/city/town? [ Default = test_locality ]:" LOCALITY
    LOCALITY=${LOCALITY:-test_locality}

    read -p "What do you want to set the certificate's email address to? [ Default = test@test.abc ]:" EMAIL
    EMAIL=${EMAIL:-test@test.abc}   

    sed -i "s/C                      = US/C                             = $COUNTRY/g" openssl.cnf
    sed -i "s/ST                     = North Carolina/ST                = $STATE/g" openssl.cnf
    sed -i "s/L                      = Cary/L                           = $LOCALITY/g" openssl.cnf
    sed -i "s/O                      = CA Technologies/O                = $ORG/g" openssl.cnf
    sed -i "s/OU                     = UIM/OU                           = $ORG_UNIT/g" openssl.cnf
    sed -i "s/CN                     = UIM QA/CN                        = $COMMON_NAME/g" openssl.cnf
    sed -i "s/emailAddress           = test@email.address/emailAddress  = $EMAIL/g" openssl.cnf    
}   

function Ending_Tasks {

    case $SSL_REQUEST in
        enabled | enable | yes)
            #echo Removing $TMP_CERTS_HOME/mypersonalca
            # Workaround to fix openssl TXT_DB error number 2
            #cp $TMP_CERTS_HOME/mypersonalca/index.txt.attr ..
            #cd ..
            rm -rf $TMP_CERTS_HOME/mypersonalca
            #mkdir $TMP_CERTS_HOME/mypersonalca
            #cp $TMP_CERTS_HOME/index.txt.attr $TMP_CERTS_HOME/mypersonalca
            #sed -i 's/unique_subject = yes/unique_subject = no/g' $TMP_CERTS_HOME/mypersonalca/index.txt.attr
            echo
            echo SSL should now be enabled, try logging into your DA with this URL:
            echo
            echo "https://`hostname`:8582"
            echo
            echo Completed configuring SSL
            date
            echo
            echo Sleeping for 30 seconds to ensure the CAPC Services are completely up again
            sleep 30
            ;;
        disabled | disable | no)
            echo SSL should now be disabled, try loggin into your CAPC with this URL:
            echo
            echo "http://`hostname`:8581"
            echo
            echo Completed disabling SSL
            date
            echo Sleeping for 30 seconds to ensure the DA Services are completely up again
            sleep 30
            ;;
        *)
            #echo Removing $TMP_CERTS_HOME/mypersonalca
            rm -rf $TMP_CERTS_HOME/mypersonalca
            echo
            echo SSL should now be enabled, try logging into your CAPC with this URL:
            echo
            echo "https://`hostname`:8582"
            echo
            echo Completed configuring SSL
            echo
            echo Sleeping for 30 seconds to ensure the DA Services are completely up again
            sleep 30
            ;;
    esac

}

function generate_and_import_keys {
    cd $TMP_CERTS_HOME/mypersonalca

    echo Generate the Certificate
    openssl req -new -keyout server.key -out server.csr -config openssl.cnf -nodes
    openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt 
    
    echo Save off original keystore and cacerts in case things go awry
    cd $DA_HOME/apache-karaf-2.4.3/etc/
    if [ -f keystore ]; then
        mv keystore keystore.bak
    fi    

    if [ -f truststore ]; then
        mv truststore truststore.bak
    fi    

    cd $TMP_CERTS_HOME/mypersonalca
        
    echo Create PKCS12 keystore with the server certificate
    openssl pkcs12 -inkey server.key -in server.crt -export -out server.pkcs12
        
    echo Transform the keystore into JKS format
    keytool -importkeystore -srckeystore server.pkcs12 -srcstoretype pkcs12 -destkeystore keystore.jks
    
    echo Create truststore with server certificate
    keytool -import -file server.crt -alias sscada -keystore truststore.jks
    
    echo Copy keystore and truststore to DA Karaf etc directory
    cp -f keystore.jks $DA_HOME/apache-karaf-2.4.3/etc/keystore
    cp -f truststore.jks $DA_HOME/apache-karaf-2.4.3/etc/truststore
}

function Modify_config_files {
    
	  # Setup CONFIGFILE 
    CONFIGFILE=$DA_HOME/apache-karaf-2.4.3/etc/org.ops4j.pax.web.cfg
    SYSTEMFILE=$DA_HOME/apache-karaf-2.4.3/etc/system.properties
    # echo "CONFIGFILE is "$CONFIGFILE
    
    echo Backup the $CONFIGFILE and $SYSTEMFILE files
    if [ -f "$CONFIGFILE" ]; then
        mv $DA_HOME/apache-karaf-2.4.3/etc/org.ops4j.pax.web.cfg $DA_HOME/apache-karaf-2.4.3/etc/org.ops4j.pax.web.cfg.bak
    fi

    if [ -f "$SYSTEMFILE" ]; then
        mv $DA_HOME/apache-karaf-2.4.3/etc/system.properties $DA_HOME/apache-karaf-2.4.3/etc/system.properties.bak
    fi
    	
	  cd $HOME_DIRECTORY
	  cp -f org.ops4j.pax.web.cfg $DA_HOME/apache-karaf-2.4.3/etc/
    
    case $SSL_REQUEST in
    enabled | enable )
		echo Modifying $CONFIGFILE file
		sed -i 's/org.osgi.service.http.enabled=true/org.osgi.service.http.enabled=false/' $CONFIGFILE
		sed -i 's/org.osgi.service.http.secure.enabled=false/org.osgi.service.http.secure.enabled=true/' $CONFIGFILE
		sed -i 's/#org.osgi.service.http.port.secure=8582/org.osgi.service.http.port.secure=8582/' $CONFIGFILE
		sed -i 's/org.osgi.service.http.port=8581/#org.osgi.service.http.port=8581/' $CONFIGFILE
		echo Modifying $SYSTEMFILE file	  
		sed -i 's/#javax.net.ssl.keyStore/javax.net.ssl.keyStore/' $SYSTEMFILE
		sed -i 's/#javax.net.ssl.keyStorePassword/javax.net.ssl.keyStorePassword/' $SYSTEMFILE
		sed -i 's/#javax.net.ssl.trustStore/javax.net.ssl.trustStore/' $SYSTEMFILE
		sed -i 's/#javax.net.ssl.trustStorePassword/javax.net.ssl.trustStorePassword/' $SYSTEMFILE            
    ;;
    disabled | disable)
		echo Reverting original $CONFIGFILE file back
        sed -i 's/org.osgi.service.http.enabled=false/org.osgi.service.http.enabled=true/' $CONFIGFILE
        sed -i 's/org.osgi.service.http.secure.enabled=true/org.osgi.service.http.secure.enabled=false/' $CONFIGFILE
        sed -i 's/org.osgi.service.http.port.secure=8582/#org.osgi.service.http.port.secure=8582/' $CONFIGFILE
        sed -i 's/#org.osgi.service.http.port=8581/org.osgi.service.http.port=8581/' $CONFIGFILE 
        echo Reverting original $SYSTEMFILE file back 
        sed -i 's/javax.net.ssl.keyStore=/#javax.net.ssl.keyStore/' $SYSTEMFILE
        sed -i 's/javax.net.ssl.keyStorePassword/#javax.net.ssl.keyStorePassword/' $SYSTEMFILE
        sed -i 's/javax.net.ssl.trustStore=/#javax.net.ssl.trustStore/' $SYSTEMFILE
        sed -i 's/javax.net.ssl.trustStorePassword/#javax.net.ssl.trustStorePassword/' $SYSTEMFILE 
    ;;
    *)
    echo "I don't understand, please try again"
    exit 1
    ;;
    esac  
}

function Restart_DA_Service {
    echo Restarting CAPC service
    service dadaemon stop
    sleep 10
    service dadaemon start
}


function main_menu {
    echo
    echo -e "${BLUE}G'Day and welcome to DA_SSL (Script for SSL)${NORMAL}"
    echo "==================================================================="
    echo ""
    echo -e "   Apache is ${COLOR} "$APACHE_STATUS" ${NORMAL}  SSL is currently: "$SSL_STATUS"  "
    echo ""
    echo "-------------------------------------------------------------------"

    read -p "Would you like to ${SSL_REQUEST} SSL on your DA? [ Default = yes ] " SSL_ANSWER
    SSL_ANSWER=${SSL_ANSWER:-yes}

    case $SSL_ANSWER in
        no | n)
	         # echo SSO_REQUEST is $SSO_REQUEST
           echo Thanks, goodbye !
	          ;;
        yes | y)
	         echo SSL_ANSWER is $SSL_ANSWER
             case $SSL_REQUEST in
               enabled | enable )
                 echo SSL_REQUEST is $SSL_REQUEST
                 # Ask if they already have a certificate and key
                 read -p "Do you have a signed certificate and key? [ Default = no ]:" HAVE_CERT
                 HAVE_CERT=${HAVE_CERT:-no}
                 #echo HAVE_CERT is $HAVE_CERT
                 case $HAVE_CERT in
                   no | n)
                   # Don't have a certificate, create one for me
                   echo "Don't have a certificate, create one for me"
                   setup
                   generate_and_import_keys
                   Modify_config_files
                   Restart_DA_Service                   
                   Ending_Tasks
                   status_checks
                   main_menu
                   ;;
                   yes | y)
                   # Already have a certificate, skip some of the setup steps
                   echo "Already have a certificate, skip some of the setup steps"
                   
                   ;;
                   *)
                   echo "I don't understand, please try again"
                   exit 1
                   ;;
                   esac
             ;;
             disabled | disable)
                 echo SSL_REQUEST is $SSL_REQUEST
                 Modify_config_files
				 Restart_DA_Service
				 Ending_Tasks
             ;;
             *)
             echo "I don't understand, please try again"
             exit 1
             ;;
             esac
           ;;
           *)
           echo "I don't understand, please try again"
           exit 1
           ;;
           esac
  }

status_checks
main_menu

