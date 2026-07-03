/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Погодин Илья
 * Дата: 15.06.26 г.
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Запрос 1: общая доля платящих игроков
SELECT 
    COUNT(*) AS total_players,
    SUM(payer) AS paying_players,
    AVG(payer) AS paying_share
FROM fantasy.users;

--Доля платящих игроков: ≈ 17,7%
--Примерно каждый шестой зарегистрированный игрок совершал покупку внутриигровой валюты 
--за реальные деньги. Это достаточно высокая конверсия для free-to-play проекта 
--(средний показатель по индустрии обычно составляет 1–5%). Такая доля может свидетельствовать 
--об удачной монетизации, привлекательных предложениях или высокой вовлечённости аудитории. 

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
    r.race,
    SUM(u.payer) AS paying_players,
    COUNT(u.id) AS total_players,
    AVG(u.payer) AS paying_share
FROM fantasy.users u
JOIN fantasy.race r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY paying_share DESC;

--Демоны лидируют с долей 19,37%, хоббиты занимают второе место 18,06%.
--Существует небольшая, но заметная зависимость между расой персонажа и склонностью к платежам. 
--Игроки, выбравшие демонов и хоббитов, чуть чаще становятся платящими.


-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
    COUNT(*) AS total_purchases,
    SUM(amount) AS total_revenue,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    AVG(amount) AS avg_amount,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
    STDDEV(amount) AS stddev_amount
FROM fantasy.events;

--Всего покупок: 1 307 678, общая выручка: 686,6 млн.
--Медиана (74,86) значительно ниже среднего (525,69), следовательно большинство покупок мелкие, но есть крупные.
--Высокое стандартное отклонение (2517) подтверждает разброс.


-- 2.2: Аномальные нулевые покупки:
SELECT 
    COUNT(*) FILTER (WHERE amount = 0) AS zero_purchases,
    COUNT(*) AS total_purchases,
    (COUNT(*) FILTER (WHERE amount = 0) * 100.0 / COUNT(*)) AS zero_share_percent
FROM fantasy.events;

--907 нулевых покупок (<0,07% от всех). Не влияют на выручку, исключаются из дальнейшего анализа.

-- 2.3: Популярные эпические предметы:
WITH non_zero_purchases AS (
    SELECT 
        e.item_code,
        e.id AS user_id
    FROM fantasy.events e
    WHERE e.amount > 0
),
buyer_count AS (
    SELECT COUNT(DISTINCT user_id) AS total_buyers 
    FROM non_zero_purchases
),
item_stats AS (
    SELECT 
        i.game_items AS item_name,
        COUNT(*) AS purchase_count,
        COUNT(DISTINCT nzp.user_id) AS unique_buyers,
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS purchase_share_percent
    FROM non_zero_purchases nzp
    JOIN fantasy.items i ON nzp.item_code = i.item_code
    GROUP BY i.game_items, i.item_code
)
SELECT 
    item_name,
    purchase_count,
    purchase_share_percent,
    unique_buyers,
    unique_buyers * 100.0 / (SELECT total_buyers FROM buyer_count) AS buyer_share_percent
FROM item_stats
ORDER BY unique_buyers DESC;

--Book of Legends и Bag of Holding доминируют: 97,7% продаж, охват ~88% покупателей.
--Остальные 182 предмета дают лишь 2,3% продаж («длинный хвост»).
--Выявлен дубль названия «Treasure Map» (два разных item_code) – не влияет на топ-2, 
--но при более детальном анализе предметы с одинаковым именем можно объединять.

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH
players_per_race AS (
    SELECT 
        r.race_id,
        r.race,
        COUNT(u.id) AS total_players
    FROM fantasy.users u
    JOIN fantasy.race r ON u.race_id = r.race_id
    GROUP BY r.race_id, r.race
),
buyers_stats AS (
    SELECT 
        u.id AS user_id,
        u.race_id,
        u.payer,
        COUNT(e.transaction_id) AS purchase_count,
        SUM(e.amount) AS total_spent
    FROM fantasy.users u
    JOIN fantasy.events e ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY u.id, u.race_id, u.payer
),
buyers_aggregated AS (
    SELECT 
        b.race_id,
        COUNT(DISTINCT b.user_id) AS buyers,
        SUM(b.purchase_count) AS total_purchases,
        SUM(b.total_spent) AS total_revenue,
        SUM(b.payer) AS paying_among_buyers   
    FROM buyers_stats b
    GROUP BY b.race_id
)
SELECT 
    p.race,
    p.total_players,
    COALESCE(b.buyers, 0) AS buyers,
    COALESCE(b.buyers, 0) * 1.0 / p.total_players AS buyers_share,
    COALESCE(b.paying_among_buyers, 0) * 1.0 / NULLIF(b.buyers, 0) AS paying_share_among_buyers,
    COALESCE(b.total_purchases, 0) * 1.0 / NULLIF(b.buyers, 0) AS avg_purchases_per_buyer,
    COALESCE(b.total_revenue, 0) * 1.0 / NULLIF(b.total_purchases, 0) AS avg_cost_per_purchase,
    COALESCE(b.total_revenue, 0) * 1.0 / NULLIF(b.buyers, 0) AS avg_total_spent_per_buyer
FROM players_per_race p
LEFT JOIN buyers_aggregated b ON p.race_id = b.race_id
ORDER BY p.race;

--Различия между расами есть, но они не драматичны. 
--Гипотеза о том, что некоторые расы требуют больше покупок, частично подтверждается 
--(у ангелов и людей больше число покупок, но они тратят меньше за раз). 
--Для выравнивания сложности можно обратить внимание на расы с низкой долей покупателей 
--(например, демоны – 60% против 63% у орков) или с низкой суммой трат.


