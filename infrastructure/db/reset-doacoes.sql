-- Apaga todos os dados de doação e reserva, mantendo as contas: usuários,
-- organizações, endereços, vínculos usuário-organização, tokens e nós.
--
-- Uso (produção, na pasta do projeto na VPS):
--   docker compose -f docker-compose.prod.yml exec -T postgres \
--     psql -U foodshare -d foodshare -v ON_ERROR_STOP=1 < infrastructure/db/reset-doacoes.sql
--
-- Tudo roda numa transação: se algum passo falhar, nada é apagado.
BEGIN;

-- Todo tipo de notificação aponta para doação, reserva ou chat (inclusive as
-- GENERIC, usadas só para "doação cancelada pelo doador").
DELETE FROM notifications;

-- Ordem respeita as FKs sem cascade: filhos antes dos pais.
DELETE FROM messages;
DELETE FROM conversations;
DELETE FROM pickups;
DELETE FROM reservation_items;
DELETE FROM reservations;
DELETE FROM donation_items;
DELETE FROM audit_logs
 WHERE "donationListId" IS NOT NULL
    OR entity IN ('DonationList', 'Reservation', 'Pickup');
DELETE FROM donation_lists;
DELETE FROM donation_templates;

-- Outbox de sincronização: só os eventos de doação/reserva; os de cadastro e
-- aprovação de organização continuam no painel administrativo.
DELETE FROM sync_events
 WHERE "eventType" LIKE 'DONATION%'
    OR "eventType" LIKE 'RESERVATION%'
    OR "eventType" = 'PICKUP_CONFIRMED';

-- Reputação é derivada das retiradas e no-shows que acabaram de ser apagados.
UPDATE organizations SET "completedPickupCount" = 0, "noShowCount" = 0;

COMMIT;
