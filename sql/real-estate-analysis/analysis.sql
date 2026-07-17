/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Погодин Илья
 * Дата: 16.07.2026 г.
*/


-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Подготовим данные: категоризация по региону и по времени активности,
-- расчёт стоимости кв. метра, фильтрация по городам и годам 2015-2018.
-- Категоризацию региона делаем по city_id (первичный ключ): id Санкт-Петербурга
-- получаем подзапросом из справочника city, чтобы не опираться на текст (в нём
-- возможны дубликаты) и не хардкодить конкретное значение ключа:
categorized AS (
    SELECT
        CASE
            WHEN f.city_id = (SELECT city_id FROM real_estate.city WHERE city = 'Санкт-Петербург')
                THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS region,
        CASE
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
            WHEN a.days_exposition > 180 THEN '181+ days'
            ELSE 'non category'   -- активные объявления (days_exposition IS NULL)
        END AS activity_segment,
        a.last_price / f.total_area AS price_sqm,
        f.total_area,
        f.rooms,
        f.balcony,
        f.floor,
        f.ceiling_height,
        f.open_plan
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    WHERE f.id IN (SELECT id FROM filtered_id)
      AND f.type_id = (SELECT type_id FROM real_estate.type WHERE type = 'город')
      AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
)
-- Итоговая сводная таблица по сегментам активности в разрезе регионов:
SELECT
    region,
    activity_segment,
    COUNT(*) AS ads_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY region), 2) AS share_in_region_pct,
    ROUND(AVG(price_sqm)::numeric, 2) AS avg_price_sqm,
    ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor,
    ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
    ROUND(AVG(open_plan) * 100.0, 2) AS open_plan_share_pct
FROM categorized
GROUP BY region, activity_segment
ORDER BY region DESC,
         CASE activity_segment
             WHEN '1-30 days' THEN 1
             WHEN '31-90 days' THEN 2
             WHEN '91-180 days' THEN 3
             WHEN '181+ days' THEN 4
             ELSE 5
         END;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
-- Подготовим данные: только города, считаем дату снятия объявления:
prepared AS (
    SELECT
        a.id,
        a.first_day_exposition,
        a.first_day_exposition + (a.days_exposition * INTERVAL '1 day') AS last_day_exposition,
        a.last_price / f.total_area AS price_sqm,
        f.total_area
    FROM real_estate.advertisement AS a
    JOIN real_estate.flats AS f ON a.id = f.id
    WHERE f.id IN (SELECT id FROM filtered_id)
      AND f.type_id = (SELECT type_id FROM real_estate.type WHERE type = 'город')
),
-- Статистика по месяцам публикации объявлений (полные годы 2015-2018).
-- Название месяца выводим на русском через TO_CHAR (перед запуском один раз
-- выполнить: set lc_time = 'ru_RU'; чтобы локаль вернула русские названия):
published AS (
    SELECT
        EXTRACT(MONTH FROM first_day_exposition)::int AS month_num,
        TRIM(TO_CHAR(first_day_exposition, 'TMMonth')) AS month_name,
        COUNT(*) AS published_count,
        ROUND(AVG(price_sqm)::numeric, 2) AS avg_price_sqm_pub,
        ROUND(AVG(total_area)::numeric, 2) AS avg_area_pub
    FROM prepared
    WHERE EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
    GROUP BY 1, 2
),
-- Статистика по месяцам снятия объявлений.
-- Условие отбора — по году ПУБЛИКАЦИИ (2015-2018); месяц снятия учитываем
-- независимо от того, в каком году произошло снятие:
removed AS (
    SELECT
        EXTRACT(MONTH FROM last_day_exposition)::int AS month_num,
        COUNT(*) AS removed_count,
        ROUND(AVG(price_sqm)::numeric, 2) AS avg_price_sqm_rem,
        ROUND(AVG(total_area)::numeric, 2) AS avg_area_rem
    FROM prepared
    WHERE last_day_exposition IS NOT NULL
      AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
    GROUP BY 1
)
-- Объединяем статистику публикаций и снятий в одну таблицу по месяцам.
-- Выводим название месяца, сортировку сохраняем по номеру месяца:
SELECT
    p.month_name,
    p.published_count,
    RANK() OVER (ORDER BY p.published_count DESC) AS rank_published,
    r.removed_count,
    RANK() OVER (ORDER BY r.removed_count DESC) AS rank_removed,
    p.avg_price_sqm_pub,
    p.avg_area_pub,
    r.avg_price_sqm_rem,
    r.avg_area_rem
FROM published AS p
JOIN removed AS r ON p.month_num = r.month_num
ORDER BY p.month_num;
