#!/bin/bash
# Pošle test e-mail přes Joomla mailer (= ověří, že configure-joomla-mail.sh +
# SMTP konfigurace v configuration.php fungují end-to-end). Joomla 5 v admin UI
# žádné "Send Test Mail" tlačítko nemá (existovalo v Joomle 3), takže test
# pohodlně provedeme z CLI.
#
# Skript naloaduje Joomla framework (modelováno podle cli/joomla.php) a zavolá
# Factory::getMailer()->Send() s test obsahem. Pokud SMTP funguje, zpráva
# dorazí do Mailpitu (http://localhost:8025).
set -euo pipefail

cd "$(dirname "$0")/.."

if ! docker compose ps --services --status running | grep -qx joomla; then
  echo "Joomla kontejner neběží — spusť napřed ./scripts/up.sh"
  exit 1
fi

echo "Posílám test mail přes Joomla mailer..."

docker compose exec -T -u www-data joomla php <<'PHP'
<?php
const _JEXEC = 1;
require_once '/var/www/html/administrator/includes/defines.php';
require_once JPATH_BASE . '/includes/framework.php';

$container = \Joomla\CMS\Factory::getContainer();
$container->alias('session', 'session.cli')
    ->alias('JSession', 'session.cli')
    ->alias(\Joomla\CMS\Session\Session::class, 'session.cli')
    ->alias(\Joomla\Session\Session::class, 'session.cli')
    ->alias(\Joomla\Session\SessionInterface::class, 'session.cli');

$app = $container->get(\Joomla\Console\Application::class);
\Joomla\CMS\Factory::$application = $app;

$mailer = \Joomla\CMS\Factory::getMailer();
$mailer->setSender(['admin@example.com', 'VirtueMart Dev']);
$mailer->addRecipient('test-recipient@example.com');
$mailer->setSubject('Test mail z send-test-mail.sh (' . date('c') . ')');
$mailer->setBody("Pokud tuhle zprávu vidíš v Mailpitu, Joomla mail config funguje\n"
    . "a SMTP směruje přes kontejner mailpit:1025.\n");

try {
    $ok = $mailer->Send();
    if ($ok === true) {
        fwrite(STDOUT, "Odesláno OK.\n");
        exit(0);
    }
    fwrite(STDERR, "Send vrátil neúspěch: " . var_export($ok, true) . "\n");
    exit(2);
} catch (\Throwable $e) {
    fwrite(STDERR, get_class($e) . ': ' . $e->getMessage() . "\n");
    exit(3);
}
PHP

cat <<EOF

Otevři Mailpit a měla by tam být nová zpráva:
  http://localhost:8025
EOF
