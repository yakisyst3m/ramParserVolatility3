#!/bin/bash

# Le script utilise volatility3 pour une liste d'images dans un même dossier.
# Il fait des exports en csv et xlsx de chaque commande volatility
# Lancer le script de cette façon :
# ramParserVolatility3 -d dossierContenantLesImages
#
# fonctionne pour des images raw / dd / memm /dmp / vmem

#2022 03 31     v1.0-beta
#2022 04 01     v1.0-beta    modif global du code
#2022 04 02     v1.0-beta    changement de convertisseur + correction ramParser
#2022 11 21     v1.0-beta    vérif pré-requis
#2022 11 22     v1.0         entière modification


utilisateur=$(grep 1000 /etc/passwd | awk -F ":" '{print $1}')
rouge='\e[1;31m'
vert='\e[1;32m'
bleu='\e[1;34m' 
neutre='\e[0;m'

# Vérification des paramètres
if [[ "$1" == "-d"  ]] && [[ ! -z "$2" ]] && [[ -d "$2" ]] ; then
    while getopts ":h:help:d:" opt ; do
        case "${opt}" in 
            "h|help") 
                aide ;;
            "d")
                cheminImagesRaw=${OPTARG} ;;
            "*")
                break ;;
        esac
    done
else
    aide && exit 0
fi    

# Vérif Comm Internet
internetTestOK(){
    ping -q -c1 9.9.9.9 -W 2 >/dev/null 2>&1
}

######## DECOMPTE 
decompte() {
    i=$1
    echo " "
    while [[ $i -ge 0 ]] ; do
            echo -e "${rouge}\r "$i secondes" \c ${neutre}"
            sleep 1
            i=$(("$i"-1))
    done
    echo -e "\n${vert} Fin du décompte ${neutre}"
}

# Installation des pré-requis
verifInstall_csv2xlsx() {
    echo -e "\n##############################################\n"
    echo -e "\n${bleu}[ ---- Vérification installation de csv2xlsx ---- ]${neutre}\n"
    if [[ ! -f "/usr/local/bin/csv2xlsx" ]] ; then
        cp res/csv2xlsx_linux_amd64 /opt/csv2xlsx
        chmod +x /opt/csv2xlsx
        chown $utilisateur: /opt/csv2xlsx
        ln -s /opt/csv2xlsx /usr/local/bin && echo -e "${vert} [ OK ] csv2xlsx a été installé ${neutre}"
        csv2xlsx --help
        decompte 3
    else
        echo -e "${vert} [ OK ] csv2xlsx est déjà installé ${neutre}"
        decompte 3
    fi
}

verifInstall_vol3() {
    echo -e "\n##############################################\n"
    echo -e "\n${bleu}[ ---- Vérification installation de Volatility 3 ---- ]${neutre}\n"

        if [[ -f "/usr/local/bin/vol3.py" ]] && [[ -d "/home/$utilisateur/.volatility3/" ]] || [[ -f "/usr/local/bin/vol.py" ]] && [[ -d "/home/$utilisateur/.volatility3/" ]] ; then
            echo -e "${vert} [ OK ] Volatility 3 est déjà installé ${neutre}"
        elif [[ ! -f "/usr/local/bin/vol3.py" ]] || [[ ! -f "/usr/local/bin/vol.py" ]]; then
            internetTestOK
            if [[ "$?" = "0" ]] ; then
               # Préparation avant installation
                cd /home/"$utilisateur"/
                echo "Début de l'installation et des mises à jour de Volatility 3:"
                echo "Installation des librairies"
                apt update && apt install -y build-essential git libdistorm3-dev yara libraw1394-11 libcapstone-dev capstone-tool tzdata  && echo -e "${vert} [ OK ] Modules afférent à Volatility 3 installés ${neutre}"
                decompte 1

                # Installation de python 3
                echo "Installation des outils python 3"
                apt install -y python3 python3-dev libpython3-dev python3-pip python3-setuptools python3-wheel git && echo -e "${vert} [ OK ] Outils python pour Volatility 3 installés ${neutre}"

                if [[ ! -d "/home/$utilisateur/.volatility3/" ]] ; then
                    # Téléchargement de volatility 3
                    git clone https://github.com/volatilityfoundation/volatility3.git
                    mv volatility3 /home/"$utilisateur"/.volatility3
                fi
                
                # Téléchargement de la table des symbols windows
                cd /home/"$utilisateur"/.volatility3/volatility3/symbols/
                wget https://downloads.volatilityfoundation.org/volatility3/symbols/windows.zip
                unzip windows.zip
                
                # Renommage 
                cd /home/"$utilisateur"/.volatility3
                mv vol.py vol3.py
                chmod -R 750 ../.volatility3/
                chown -R "$utilisateur": ../.volatility3/
                
                # Installation des modules volatility
                pip3 install -r requirements.txt
                
                # Lien pour lancer l'application
                ln -s /home/"$utilisateur"/.volatility3/vol3.py /usr/local/bin/vol3.py && echo -e "${vert} [ OK ] Volatility 3 a été installé ${neutre}"
                
                # TestMAJ
                vol3.py -h
                decompte 3
            else
                echo -e "${rouge} [ NOK ] Il n'y a pas de connection internet pour installer Volatility, veuillez mettre en réseau la machine ... ${neutre}"
                exit
            fi
        elif [[ -d "/home/$utilisateur/.volatility3/" ]] && [[ ! -d "/home/$utilisateur/.volatility3/volatility3/symbols/windows/" ]] ; then
            internetTestOK
            if [[ "$?" = "0" ]] ; then 
                # Téléchargement de la table des symbols windows
                cd /home/"$utilisateur"/.volatility3/volatility3/symbols/
                wget https://downloads.volatilityfoundation.org/volatility3/symbols/windows.zip
                unzip windows.zip
            
                # Renommage 
                cd /home/"$utilisateur"/.volatility3
                mv vol.py vol3.py
                chmod -R 750 ../.volatility3/
                chown -R "$utilisateur": ../.volatility3/
            else
                echo -e "${rouge} [ NOK ] Il n'y a pas de connection internet pour installer Volatility, veuillez mettre en réseau la machine ... ${neutre}"
                exit
            fi
        else
            echo -e "${vert} [ OK ] Volatility 3 est déjà installé ${neutre}"
        fi

}


# Fonction Aide
function aide() {
	echo -e "\n${vert}\t[ - Aide pour utiliser la commande : - ]${neutre}"
    echo -e	"\tramParserVolatility3 [option] <dossier de recherche>\n"
    echo -e "\t\t\t\t-h ou --help\tAide" 
    echo -e "\t\t\t\t-d\t\tChemin du dossier de recherche\n"
    exit 0
}



# Variables
cpt=1   # compteur d'image à analyser
imagesRaw=$(find $cheminImagesRaw -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.(dd|raw|mem|dmp|vmem)$')
chemin=$(pwd)

# Fonctions
function csv2xlsx() {
    echo -e "\n##############################################\n"
    echo -e "${bleu}\n\t[ --    Conversion :  CSV vers XLSX    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
    find "$UCNAME/CSV/" -type f -name "*.csv" -exec csv2xlsx -infile {} -outfile {}'.xlsx' -colsep '\t' -columns 0-20 \;
    find "$UCNAME/CSV/" -type f -name "*.xlsx" -exec mv {} "$UCNAME/XLSX/" \;
}

function ControleIntegriteFic() {
    echo -e "\n##############################################\n"
    echo -e "${bleu}\n\t[ --    Contrôle d'intégité des fichiers    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
    echo -e "\n${bleu}\t\t[  -   Contrôle des empreintes numériques des exports CSV -   Exports RAM N°$cpt / MEMORY NAME : $UCNAME  -   ]${neutre}"
    echo -e "\n\t\t[  -   Contrôle des empreintes numériques des exports CSV -   Exports RAM N°$cpt / MEMORY NAME : $UCNAME  -   ]\n" > "$UCNAME"/CSV/hash_csv_"$UCNAME".txt
    for ficsv in $(ls $UCNAME/CSV/*.csv) ; do
        (echo -e "MD5: \c" && md5sum $ficsv) | tee -a "$UCNAME"/CSV/hash_csv_"$UCNAME".txt
        (echo -e "SHA1: \c" && sha1sum $ficsv) | tee -a "$UCNAME"/CSV/hash_csv_"$UCNAME".txt
        (echo -e "SHA256: \c" && sha256sum $ficsv) | tee -a "$UCNAME"/CSV/hash_csv_"$UCNAME".txt
        echo ""
        echo " " >> "$UCNAME"/CSV/hash_csv_"$UCNAME".txt
    done
    
    echo -e "\n${bleu}\t\t[  -   Contrôle des empreintes numériques des exports XLSX -   Exports Machine N°$cpt / Nom de Machine : $UCNAME  -   ]${neutre}"
    echo -e "\n\t\t[  -   Contrôle des empreintes numériques des exports XLSX -   Exports Machine N°$cpt / Nom de Machine : $UCNAME  -   ]\n" > "$UCNAME"/XLSX/hash_xlsx_"$UCNAME".txt
    for fixlsx in $(ls $UCNAME/XLSX/*.xlsx) ; do
        (echo -e "MD5: \c" && md5sum $fixlsx) | tee -a "$UCNAME"/XLSX/hash_xlsx_"$UCNAME".txt
        (echo -e "SHA1: \c" && sha1sum $fixlsx) | tee -a "$UCNAME"/XLSX/hash_xlsx_"$UCNAME".txt
        (echo -e "SHA256: \c" && sha256sum $fixlsx) | tee -a "$UCNAME"/XLSX/hash_xlsx_"$UCNAME".txt
        echo ""
        echo "" >> "$UCNAME"/XLSX/hash_xlsx_"$UCNAME".txt
    done
}

function ControleIntegriteMEM() {
    echo -e "\n##############################################\n"
    echo -e "\n${bleu}\t[  -   Contrôle de l'empreinte numérique de l'image RAM  -   RAM N°$cpt / MEMORY NAME : $UCNAME  -   ]${neutre}"        
    echo -e "\n\t[  -   Contrôle de l'empreinte numérique de l'image RAM  -   RAM Machine N°$cpt / Nom de Machine : $UCNAME  -   ]\n" > "$UCNAME"/hash_RAM_"$UCNAME".txt
    
    echo -e "- Analyse MD5 en cours - Veuillez patienter - Les résultats seront dans le fichiers : "$UCNAME"/hash_RAM_"$UCNAME".txt "
    md5sum $imageTrouvee >> "$UCNAME"/hash_RAM_"$UCNAME".txt &
    
    echo -e "- Analyse SHA1 en cours -  Veuillez patienter - Les résultats seront dans le fichiers : "$UCNAME"/hash_RAM_"$UCNAME".txt "
    sha1sum $imageTrouvee >> "$UCNAME"/hash_RAM_"$UCNAME".txt &
    
    echo -e "- Analyse SHA256 en cours -  Veuillez patienter - Les résultats seront dans le fichiers : "$UCNAME"/hash_RAM_"$UCNAME".txt "
    sha256sum $imageTrouvee >> "$UCNAME"/hash_RAM_"$UCNAME".txt &
}

# Fenêtre de résultat pour chaque image mémoire
function resultats() {
   echo -e "${bleu}\n\t[ --    Résultats    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
   echo -e "\n${vert}=============================================     RAPPORT RAM MEMORY N°$cpt TERMINÉE : $UCNAME       ===============================================${neutre}\n"
        echo -e "${vert}\t[  - Export CSV - liste des fichiers : ${rouge}$chemin/$UCNAME/CSV/ ]${neutre}"
        ls -liah "$UCNAME"/CSV/
        echo -e "\n${vert}\t[  - Export XLSX - liste des fichiers : ${rouge}$chemin/$UCNAME/XLSX/ ]${neutre}"
        ls -liah "$UCNAME"/XLSX/
   echo -e "\n${vert}===================================================================================================================================================${neutre}\n"

   echo -e "\n=============================================     RAM MEMORY N° $cpt TERMINÉE : $UCNAME       ===============================================\n" > "$UCNAME"/Rapport_resultats_"$UCNAME".txt
        echo -e "\n================================     RAM     ================================" >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt
        cat "$UCNAME"/hash_RAM_"$UCNAME".txt >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt
        
        echo -e "\n================================     CSV     ================================" >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt
        echo -e "\n\n\t[  - Export CSV - liste des fichiers CSV + hash : $chemin/$UCNAME/CSV/\n" >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt
        ls -liah "$UCNAME"/CSV/ >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt
        cat "$UCNAME"/CSV/hash_csv_"$UCNAME".txt >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt 
        
        echo -e "\n================================     XLSX     ================================" >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt
        echo -e "\n\n\t[  - Export XLSX - liste des fichiers XLSX + hash : $chemin/$UCNAME/XLSX/\n" >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt
        ls -liah "$UCNAME"/XLSX/ >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt        
        cat "$UCNAME"/XLSX/hash_xlsx_"$UCNAME".txt >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt 

   echo -e "\n==============================================================    FIN RAPPORT RAM MEMORY N° $cpt : $UCNAME        ==============================================================\n" >> "$UCNAME"/Rapport_resultats_"$UCNAME".txt
}

#################### Commandes volatility 3

volHandles(){
# ===== HANDLES (optionnel dans le programme car très long)
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  Handles : Recherche des Handles : rappels dans Processus (prog en exec) > des Threads contenant (nb instructions en exec) > des Handles : Nb d'objets en cours d'exécution    -- ]${neutre}" && sleep 1
            echo -e "${rouge}\nVoulez-vous parser la RAM avec le plugins Handles ?  (y/n) \n- Cela prendra de quelques heures à plusieurs jours en fonction de la taille de la RAM et le nombre de processus ?${neutre}" && sleep 1
            echo -e "Votre choix (y/n) : \c"
            read handlesRep
            if [ "$handlesRep" = "y" ] ; then
                    time vol3.py -f $imageTrouvee windows.handles.Handles |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_Handles.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_Handles.csv ${neutre}\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
            fi
}

volInfo(){            
            # ===== INFO
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  Info MAchine    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.info.Info |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_Info.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_Info.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

volProcess(){            
            # ===== PROCESS
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  PsList : liste des processus    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.pslist.PsList |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_PsList.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_PsList.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
            echo -e "${bleu}\n\t[ --    Volatility 3 :  PsTree : arbre des processus    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.pstree.PsTree |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_PsTree.csv && echo -e "${vert}\t [ OK ] - Fichier créé : "$UCNAME"/CSV/RAM_${UCNAME}_PsTree.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

volHivelist(){
            # ===== HIVELIST
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  Hivelist : Ruches    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.registry.hivelist.HiveList |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_HiveList.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_HiveList.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
            echo -e "${bleu}\n\t[ --    Volatility 3 :  key : Clé Run    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.registry.printkey.PrintKey --key "Software\Microsoft\Windows\CurrentVersion\Run" |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_HiveList_Key_Run.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_HiveList_Key_Run.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
            echo -e "${bleu}\n\t[ --    Volatility 3 :   key : Clé RunOnce    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.registry.printkey.PrintKey --key "Software\Microsoft\Windows\CurrentVersion\RunOnce" |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_HiveList_Key_RunOnce.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_HiveList_Key_RunOnce.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

volNetwork(){
            # ===== NETWORK
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  NetScan : Scan réseau    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.netscan.NetScan |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_NetScan.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_NetScan.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
            echo -e "${bleu}\n\t[ --    Volatility 3 :   NetStat : Statistiques réseau    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.netstat.NetStat |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_NetStat.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_NetStat.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

volServices(){                
            # ===== SERVICES      
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :   SvcScan : Scan des Services    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.svcscan.SvcScan |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_SvcScan.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_SvcScan.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

volCMD(){
            # ===== COMMAND LINE
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  CmdLine : Lignes de commandes    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.cmdline.CmdLine |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_CmdLine.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_CmdLine.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

volMalware(){
            # ===== MALWARE
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  Malfind : Recherche de Malware    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
            echo -e "${rouge}\nVoulez-vous parser la RAM avec le plugins Malfind ?  (y/n) \n- Cela prendra de pas mal de minutes en fonction de la taille de la RAM et le nombre de processus ? ${neutre}" && sleep 1
            echo -e "Votre choix (y/n) : \c"
            read malfindRep
            if [ "$malfindRep" = "y" ] ; then
                time vol3.py -f $imageTrouvee windows.malfind.Malfind |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_Malfind.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_Malfind.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
            fi
            echo -e "${bleu}\n\t[ --    Volatility 3 :  DriverIrp : Détecter les actions non légitimes des Drivers (Hook detection)    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.driverirp.DriverIrp |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_DriverIrp.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_DriverIrp.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
            echo -e "${bleu}\n\t[ --    Volatility 3 :  SSDT : System Service Descriptor Table : Vérifier les adresses des appels systèmes (emplacement non attendu)    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.ssdt.SSDT |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_SSDT.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_SSDT.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

volPass(){
            # ===== HASH / PASSWORD
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  Hashdump : Recherche des hash : SAM + SYSTEM    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.hashdump.Hashdump |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_Hashdump.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_Hashdump.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt   #    csv ok  xlsx ok
            echo -e "${bleu}\n\t[ --    Volatility 3 :  Cachedump : Recherche des hash en cache    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.cachedump.Cachedump |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_Cachedump.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_Cachedump.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt    #    csv ok             xlsx NOK
            echo -e "${bleu}\n\t[ --    Volatility 3 :  Lsadump : Recherche des secrets LSA    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.lsadump.Lsadump |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_Lsadump.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_Lsadump.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

volMutex(){
            # ===== MUTEX
            echo -e "\n##############################################\n"
            echo -e "${bleu}\n\t[ --    Volatility 3 :  MutantScan : Recherche des MUTEX    -- ]${neutre}" && sleep 1 | tee -a $UCNAME/Rapport_erreurs_"$UCNAME".txt
                time vol3.py -f $imageTrouvee windows.mutantscan.MutantScan |  tee -a "$UCNAME"/CSV/RAM_"$UCNAME"_MutantScan.csv && echo -e "${vert}\t [ OK ] - Fichier créé : $UCNAME/CSV/RAM_${UCNAME}_MutantScan.csv ${neutre}\n\n" 2>>$UCNAME/Rapport_erreurs_"$UCNAME".txt
}

###########################################     PROGRAMME       #######################################################"


# Parseur Volatility3 Windows
for imageTrouvee in $(ls $imagesRaw) ; do
    if [ ! -z "$imagesRaw" ] ; then
        cpt="$cpt"  
        echo -e "\n${vert}=============================================     MACHINE EN COURS DE PARSING : $cpt        ===============================================${neutre}"
        echo -e "${bleu}\t[   -   Image N°$cpt trouvée :     -   ]${neutre}" && file "$imageTrouvee"
        UCNAME=$(basename $imageTrouvee | cut -d "." -f1) && echo -e "\n${vert}\t [ OK ] - Création du dossier : $UCNAME ${neutre}"
        mkdir -p "$UCNAME"/{CSV,XLSX} && echo -e "${vert}\t [ OK ] - Création des dossiers : $UCNAME/CSV et $UCNAME/XLSX ${neutre}"
        
        # Vérif des pré-requis
        echo -e "${vert}\t Vérification des pré-requis : ${neutre}"
        verifInstall_vol3
        verifInstall_csv2xlsx
        
        # Integrity
        ControleIntegriteMEM
        sleep 4
        
        # Extraire les infos grâce à Volatility 3
        # Ci-dessous vous pouvez ajouter facilement les plugins qui vous intéresse
        volHandles
        volInfo
        volProcess    
        volHivelist    
        volNetwork
        volServices
        volCMD
        volMalware
        volPass
        volMutex

        # Convertir les fichiers CSV en XLSX
        csv2xlsx

        # Contrôle d'intégrité des fichiers CSV et XLSX  
        ControleIntegriteFic

        # Rapport des résultats
        resultats

        # Incrément N° de machine
        cpt=$(("$cp"+1))
    
        sleep 4
        
    else
        echo -e "\n\t${rouge}-- Il n'y a aucune image .raw .dd .mem .dmp .vmem dans ce dossier   --${neutre}\n"
    fi

done

# Ajout des droits utilisateurs
chmod -R 777 "$UCNAME"/ && chown -R "$utilisateur": "$UCNAME"/




###################### D'autres commandes volatility 3

# windows.bigpools.BigPools, windows.cachedump.Cachedump, windows.callbacks.Callbacks, windows.cmdline.CmdLine, windows.crashinfo.Crashinfo, windows.dlllist.DllList, windows.driverirp.DriverIrp, windows.driverscan.DriverScan, windows.dumpfiles.DumpFiles, windows.envars.Envars, windows.filescan.FileScan, windows.getservicesids.GetServiceSIDs, windows.getsids.GetSIDs, windows.handles.Handles, windows.hashdump.Hashdump, windows.info.Info, windows.ldrmodules.LdrModules, windows.lsadump.Lsadump, windows.malfind.Malfind, windows.memmap.Memmap, windows.mftscan.MFTScan, windows.modscan.ModScan, windows.modules.Modules, windows.mutantscan.MutantScan, windows.netscan.NetScan, windows.netstat.NetStat, windows.poolscanner.PoolScanner, windows.privileges.Privs, windows.pslist.PsList, windows.psscan.PsScan, windows.pstree.PsTree, windows.registry.certificates.Certificates, windows.registry.hivelist.HiveList, windows.registry.hivescan.HiveScan, windows.registry.printkey.PrintKey, windows.registry.userassist.UserAssist, windows.sessions.Sessions, windows.skeleton_key_check.Skeleton_Key_Check, windows.ssdt.SSDT, windows.statistics.Statistics, windows.strings.Strings, windows.svcscan.SvcScan, windows.symlinkscan.SymlinkScan, windows.vadinfo.VadInfo, windows.vadyarascan.VadYaraScan, windows.verinfo.VerInfo, windows.virtmap.VirtMap
