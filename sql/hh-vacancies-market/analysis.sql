-- Получение статистики по заработной плате
SELECT ROUND(AVG(salary_from), 2) AS avg_salary_from,
       ROUND(AVG(salary_to), 2) AS avg_salary_to,
       MIN(salary_from) AS min_salary_from,
       MAX(salary_from) AS max_salary_from,
       MIN(salary_to) AS min_salary_to,
       MAX(salary_to) AS max_salary_to
FROM public.parcing_table;

-- avg_salary_from | avg_salary_to | min_salary_from | max_salary_from | min_salary_to | max_salary_to 
-- -----------------+---------------+-----------------+-----------------+---------------+---------------
--        109525.09 |     153846.71 |            50.0 |        398000.0 |       25000.0 |      497500.0

-- Средняя зарплата в категории «от» составляет около 109525 рублей, а  
-- в категории «до» — около 153846 рублей. Это указывает на то, что работодатели готовы платить
-- аналитикам данных и системным аналитикам в среднем около 130000 рублей. 
-- Минимальная предлагаемая зарплата начинается с 50 рублей, что, скорее всего, 
-- является ошибкой данных, а максимальная достигает 497500 рублей.




-- Количество вакансий по регионам
SELECT area,
       COUNT(*) AS num_vacancies
FROM public.parcing_table
GROUP BY area
ORDER BY num_vacancies DESC;

--             area              | num_vacancies 
-- -------------------------------+---------------
--  Москва                        |          1247
--  Санкт-Петербург               |           181
--  Екатеринбург                  |            51
--  Нижний Новгород               |            33
--  Новосибирск                   |            33
-- ...  

-- Москва и Санкт-Петербург — лидеры по количеству вакансий. 
-- Это неудивительно, учитывая, что это крупнейшие города 
-- с развитой инфраструктурой и большим количеством компаний. 
-- В Екатеринбурге, Нижнем Новгороде и Новосибирске также значительное 
-- количество вакансий — это указывает на развитый рынок труда для аналитиков данных в этих регионах.




-- Количество вакансий по компаниям
SELECT employer,
       COUNT(*) AS num_vacancies 
FROM public.parcing_table 
GROUP BY employer 
ORDER BY num_vacancies DESC;
-- СБЕР — лидер (243 вакансии), далее WILDBERRIES (43), Ozon (34), Банк ВТБ (28), Т1 (26).


-- Количество вакансий по типу занятости
SELECT employment,
       COUNT(*) AS num_vacancies
FROM public.parcing_table 
GROUP BY employment 
ORDER BY num_vacancies DESC;

-- Полная занятость: 1764, частичная: 16, стажировка: 16, проектная работа: 5.


-- Количество вакансий по графику работы
SELECT schedule,
       COUNT(*) AS num_vacancies 
FROM public.parcing_table 
GROUP BY schedule 
ORDER BY num_vacancies DESC;

-- Полный день: 1441, удаленная работа: 310, гибкий график: 41, сменный график: 9.
-- Удалённая работа доступна в ~16% вакансий — это реальный сегмент рынка.


-- Выявление грейда требуемых специалистов по опыту
SELECT experience,
       COUNT(*) AS num_vacancies
FROM public.parcing_table 
GROUP BY experience 
ORDER BY num_vacancies DESC;

-- Junior+ (1-3 года): 1091, Middle (3-6): 555, Junior (без опыта): 142, Senior (6+): 13.
-- Основной спрос — Junior+ и Middle.


-- Доля грейдов среди вакансий аналитиков (фильтр по названию)
SELECT experience,
       COUNT(*) AS num_vacancies,
       ROUND(COUNT(*) * 100.0 / 1326, 2) AS percent_vacancies
FROM public.parcing_table
WHERE name LIKE '%Аналитик данных%' 
   OR name LIKE '%аналитик данных%'
   OR name LIKE '%Системный аналитик%'
   OR name LIKE '%системный аналитик%'
GROUP BY experience
ORDER BY percent_vacancies DESC;

-- Junior+: 64.4%, Middle: 26.0%, Junior (без опыта): 9.1%, Senior: 0.45%.
-- Вывод: рынок ориентирован на специалистов начального уровня.


-- Типичное место работы: работодатели и условия для аналитиков
SELECT employer,
       COUNT(*) AS num_vacancies,
       ROUND(AVG(salary_from), 2) AS avg_salary_from,
       ROUND(AVG(salary_to), 2) AS avg_salary_to,
       employment,
       schedule
FROM public.parcing_table 
WHERE name LIKE '%Аналитик данных%' OR name LIKE '%аналитик данных%' OR name LIKE '%Системный аналитик%' OR name LIKE '%системный аналитик%'
GROUP BY employer, employment, schedule 
ORDER BY num_vacancies DESC;

-- СБЕР: 117 вакансий, средняя зарплата ~110 тыс., полная занятость.
-- Крупные компании нанимают аналитиков на полную занятость.


-- Частота упоминания навыков
SELECT key_skills_1,
       COUNT(*) AS num_mention
FROM public.parcing_table 
GROUP BY key_skills_1 
ORDER BY num_mention DESC;

-- Топ навыков: Анализ данных (312), SQL (161), Документация (89), MS SQL (87).
-- SQL и документирование — ключевые требования рынка.