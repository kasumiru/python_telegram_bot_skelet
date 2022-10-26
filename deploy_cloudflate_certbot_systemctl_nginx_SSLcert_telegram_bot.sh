

# скрипт подготовки nginx domain.conf 
# domain create prepare domain 
# nginx подготовка файла 
# установка DNS записи для cloudflare account


# install certbot install 
python3 -m pip install certbot certbot-nginx certbot-dns-cloudflare


dns_cloudflare_email="xxxxxxxxxxxxxxxx@gmail.com"
cloudflare_api_key="3xxxxxxxxxxxxxxxxxxxxxxxxxx"

domain="xxxxxxxxxxxxxxxx.yyyyyyyy.com"
app_port="8108"
telegram_token="550000000:AAXYXYXYXYXYXYXYXYXYXYXYXYXY"
nginx_ssl_port="443"

stemctl_bot_name="my_telegram_bot.service"
python_bot_filename="python_telegram_bot.py"
python_bot_working_dir="/srv/tg/bot"
mkdir -p ${python_bot_working_dir}



mkdir -p /root/.certbot/cloudflare/
printf "dns_cloudflare_email = ${dns_cloudflare_email} \ndns_cloudflare_api_key = ${cloudflare_api_key}\n" > /root/.certbot/cloudflare/cloudflare.ini
printf "{\"email\":\"${dns_cloudflare_email}\",\"key\":\"${cloudflare_api_key}\"}" > /root/.certbot/cloudflare/creds_dns.json
chmod 400 /root/.certbot/cloudflare/cloudflare.ini
chmod 400 /root/.certbot/cloudflare/creds_dns.json

function adm.set_dns() {
    printf """
record = \"${1}\"
ipaddr = \"${2}\"

try:
    import requests
except Exception as e:
    import pip
    pip.main(['install', '--upgrade', 'requests'])
    import requests

import json
with open('/root/.certbot/cloudflare/creds_dns.json', 'r') as f:
    data_creds = json.load(f)

headers = {
    'Content-Type': 'application/json',
    'X-Auth-Email': data_creds['email'],
    'X-Auth-Key': data_creds['key']
    }

data = {
    'type':     'A',
    'ttl':      '60',
    'priority': 10,
    'proxied':  False,
    'name':     record,
    'content':  ipaddr
}

zone = zone   = '.'.join(record.split('.')[-2:])

def get_zone_id(zone):
    url = 'https://api.cloudflare.com/client/v4/zones'
    r = requests.get(url, headers=headers,  json='')
    ress = r.json()['result']
    for i in ress:
        if i.get('name') == zone:
            return i.get('id')

zoneid = get_zone_id(zone)

def get_dns_record_id(record):
    url = f'https://api.cloudflare.com/client/v4/zones/{zoneid}/dns_records'
    r = requests.get(url, headers=headers, json='')
    all_records = r.json()

    for i in all_records.get('result'):
        name = i['name']
        id   = i['id']
        type = i['type']
        if name == record and type == 'A':
            return id

dns_record_id = get_dns_record_id(record)
print(dns_record_id)
if dns_record_id is not None:
    url = f'https://api.cloudflare.com/client/v4/zones/{zoneid}/dns_records/{dns_record_id}'
    r = requests.delete(url, headers=headers, json='')
    print(r.text)

url = f'https://api.cloudflare.com/client/v4/zones/{zoneid}/dns_records'
r = requests.post(url, headers=headers, json=data)
print(r.text)
""" | python3
}


# DNS: set dns name by cloudflare
server_ip=`curl 2ip.ru`
# dns set A ${domain} ${server_ip} || adm.set_dns ${domain} ${server_ip}
adm.set_dns ${domain} ${server_ip}

echo ""
echo "now sleep 120 seconds"
sleep 120


# CERTIFICATE letsencrypt certbot generate cerficicate
certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.certbot/cloudflare/cloudflare.ini -d ${domain} --agree-tos --non-interactive 



# install latest nginx
sudo apt install curl gnupg2 ca-certificates lsb-release debian-archive-keyring
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
gpg --dry-run --quiet --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/debian `lsb_release -cs` nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list
apt update
apt install nginx

# nginx.conf:
cp /etc/nginx/nginx.conf{,-}
echo "###" > /etc/nginx/nginx.conf
cat /etc/nginx/nginx.conf- >> /etc/nginx/nginx.conf
sed -z "s/http {/http {\n    server_tokens off;\n/g" -i /etc/nginx/nginx.conf
# default.conf
cp /etc/nginx/conf.d/default.conf{,-}
printf "server {\n    listen       80;\n    server_name  localhost;\n    return 403;\n}" > /etc/nginx/conf.d/default.conf

systemctl restart nginx
systemctl status nginx
nginx -t && nginx -s reload
nginx -v





# nginx prepare 
rm template_domain.nginx.conf*
wget https://raw.githubusercontent.com/kasumiru/templates/main/template_domain.nginx.conf
domain_file="${domain}.conf"
default_file="template_domain.nginx.conf"
curdate=$(date '+%Y.%m.%d_%H_%M_%s')
echo -e "${Green} backup old domain conf file"
cp /etc/nginx/conf.d/${domain_file} /etc/nginx/conf.d/${domain_file}_${curdate}_bkp
cp "${default_file}" "${domain_file}"
sed -s "s/TEMPLATEDOMAIN/${domain}/g"         -i "${domain_file}"
sed -s "s/APPTCPPORT/${app_port}/g" -i "${domain_file}"
mv ${domain_file} /etc/nginx/conf.d/${domain_file}
nginx -t && nginx -s reload
rm template_domain.nginx.conf*



# WEBHOOK: регистрация телеграм webhook web hook вебхук вубхука телеграм
curl https://api.telegram.org/bot${telegram_token}/setWebhook?url=https://${domain}




# сам бот python простой автоответ
yes | python3 -m pip uninstall telebot
python3 -nm pip install pyTelegramBotAPI

# скачиваем с гитхаба скелет бота
curl https://raw.githubusercontent.com/kasumiru/python_telegram_bot_skelet/main/simple_telegram_bot_webhook.py -L > ${full_python_bot_filename}
# заменяем дефолтные переменные и токен на павильные
sed "s/telegram_bot_token_PLACEHOLDER/${telegram_token}/g" -i ${full_python_bot_filename}; head ${full_python_bot_filename}
sed "s/tcp_port = 8811/tcp_port = ${app_port}/g" -i ${full_python_bot_filename}; head ${full_python_bot_filename}




# prepare systemctl service file for python script
full_python_bot_filename="${python_bot_working_dir}/${python_bot_filename}"
full_stemctl_bot_name="/lib/systemd/system/${stemctl_bot_name}"

rm ${full_stemctl_bot_name}
rm /etc/systemd/system/${stemctl_bot_name} 
systemctl daemon-reload

echo "[Unit]" > ${full_stemctl_bot_name}
echo "Description=python telegram downloader bot" >> ${full_stemctl_bot_name}
echo "After=network.target auditd.service" >> ${full_stemctl_bot_name}
echo "" >> ${full_stemctl_bot_name}
echo "[Service]" >> ${full_stemctl_bot_name}
echo "WorkingDirectory=${python_bot_working_dir}/" >> ${full_stemctl_bot_name}
echo "ExecStart=/usr/bin/env python3 ${full_python_bot_filename}" >> ${full_stemctl_bot_name}
echo "KillMode=process" >> ${full_stemctl_bot_name}
echo "Restart=always" >> ${full_stemctl_bot_name}
echo "" >> ${full_stemctl_bot_name}
echo "[Install]" >> ${full_stemctl_bot_name}
echo "WantedBy=multi-user.target" >> ${full_stemctl_bot_name}

systemctl daemon-reload
systemctl enable ${stemctl_bot_name}
systemctl stop ${stemctl_bot_name}
systemctl restart ${stemctl_bot_name}
systemctl status ${stemctl_bot_name}



# для ручной отладки (для разработки) останавливаем systemctl файл:
systemctl stop ${stemctl_bot_name}
#запускаем и через vim запускаем хоткеем (очень советую, хоткей ctl+d, в соседнем репозитории нужно скачать и заменить .vimrc)
vim ${full_python_bot_filename}
