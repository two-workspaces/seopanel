# Deploy and Host Seo Panel on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/seo-panel?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=seo-panel)

[Seo Panel](https://www.seopanel.org/) is an open-source SEO control panel for managing many websites from one place: keyword rank tracking, a site auditor, backlink and indexed-page checks, page speed, Search Console and Google Analytics reports, sitemap generation, and scheduled reports per site and per client. It has user accounts and plans, so agencies can give each client their own login. This template runs the current release on PHP 8.3 with MariaDB, installed for you, with no setup page left open.

## About Hosting Seo Panel

The stack is two services: Seo Panel and a private MariaDB.

- **Installed from the first second.** The database is created on first boot with a generated password for the `spadmin` login. Seo Panel's web installer, and the config file it would rewrite, are blocked: the default `spadmin`/`spadmin` never exists.
- **Reports run on schedule.** The rank, backlink, saturation, page speed and analytics checks, and the site auditor, run every 15 minutes inside the service, the way Seo Panel's cron setup page asks for. No separate cron service.
- **Upgrades on redeploy.** When the image brings a new Seo Panel release, the next start applies its database upgrade before serving.
- **Current PHP.** The official image is PHP 8.1.0, which no longer gets security fixes; this one is PHP 8.3.

## Common Use Cases

- Tracking keyword positions for your own sites or a portfolio of client sites
- Auditing sites for broken links, missing titles and duplicate content on a schedule
- Giving SEO clients their own login with reports for just their sites

## Dependencies for Seo Panel Hosting

- MariaDB 11.8 (included, private network only)

### Deployment Dependencies

- [Seo Panel documentation](https://docs.seopanel.org/)
- [Template source on GitHub](https://github.com/two-workspaces/seopanel)

### Implementation Details

**Sign in** at your service's Railway domain as `spadmin` with the `SEOPANEL_ADMIN_PASSWORD` value from the Seo Panel service's Variables tab. Change the password afterwards in My Profile; the variable is only read on first boot. Then add your sites under Websites.

**Rank checks.** Seo Panel can check positions by fetching search results itself, but search engines rate-limit and block datacenter addresses like Railway's quickly. For reliable rank tracking, connect a SERP API in the Admin Panel (DataForSEO Settings, or Seo Panel API Settings), or add proxies under Proxy Manager.

**Google data.** Search Console and Analytics reports need a Google API project: add its client ID and secret under Admin Panel → Google Settings, then connect each account under Connections.

**Email.** Scheduled report emails need SMTP: set it under Admin Panel → Mail Settings, and check it with Test Email Settings. Railway only allows outbound SMTP on the Pro plan; on other plans, use an email provider's SMTP-over-HTTPS relay or skip email reports and read them in the panel.

**Memory.** About 100 MB for Seo Panel and 150 MB for MariaDB. Apache runs at most 20 processes; raise `SEOPANEL_APACHE_WORKERS` for many concurrent users.

**Custom domain.** Add it in the service's Settings → Networking, then set `SEOPANEL_URL` to `https://your.domain`: Seo Panel builds every link from it.

**Backups.** Everything Seo Panel keeps is in the MariaDB volume; enable Railway's volume backups on the MariaDB service.

## Why Deploy Seo Panel on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Seo Panel on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
