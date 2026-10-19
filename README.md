# lets-encrypt

## Generate a PFX certificate (Ubuntu 26.04)

```
sudo ./generate-pfx.sh -d example.com -d www.example.com -e you@example.com -o /etc/ssl/pfx
```

Installs certbot if needed, obtains a certificate from Let's Encrypt (port 80 must be free, or use `-m webroot:/var/www/html`), and exports `<domain>.pfx`. Use `-s` for the staging server.
