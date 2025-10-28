-- Autor: Agustin Huczok
-- Descripción: Consulta SQL para construir agregados mensuales de fraude y segmentos por retraso de notificación.

WITH base AS (
  SELECT 
    a.pay_payment_id,
    a.amount_usd,
    a.pay_status_id,
    fr.aud_ins_dt,
    a.pay_created_dt, 
    DATE_DIFF(fr.aud_ins_dt, a.pay_created_dt, DAY) AS delay_notif_fraude,
    a.fraude
  FROM `Tabla_Metricas` a 
  LEFT JOIN (
    SELECT
      pay_payment_id,
      EXTRACT(DATE FROM aud_ins_dt) AS aud_ins_dt
    FROM `Tabla_Reporte_Fraude`
    WHERE CAST(aud_ins_dt AS DATE) BETWEEN DATE '2024-08-01' AND DATE '2025-10-01'
  ) fr 
  ON a.pay_payment_id = fr.pay_payment_id
  WHERE a.pay_created_dt BETWEEN DATE '2024-08-01' AND DATE '2025-10-01'
    AND a.sit_site_id = 'ARG'
),
q AS (
  SELECT
    b.*,
    DATE(b.pay_created_dt) AS pay_created_date,
    DATE_TRUNC(DATE(b.pay_created_dt), MONTH) AS primer_dia_mes
  FROM base b
),
q_calc AS (
  SELECT
    q.*,
    FORMAT_DATE('%Y-%m', primer_dia_mes) AS mes, 
    CASE 
      WHEN q.delay_notif_fraude <= 30 THEN 30 
      WHEN q.delay_notif_fraude <= 60 THEN 60 
      WHEN q.delay_notif_fraude <= 90 THEN 90 
      WHEN q.delay_notif_fraude <= 120 THEN 120
      ELSE 999 
    END AS delay_notif_fraude_tag
  FROM q
)
SELECT
  mes,
  -- Monto total de fraude y por intervalos
  SUM(CASE WHEN fraude = 1 THEN amount_usd ELSE 0 END) AS fraude_total,
  SUM(CASE WHEN fraude = 1 AND delay_notif_fraude_tag <= 30  THEN amount_usd ELSE 0 END) AS fraude_30dias,
  SUM(CASE WHEN fraude = 1 AND delay_notif_fraude_tag <= 60  THEN amount_usd ELSE 0 END) AS fraude_60dias,
  SUM(CASE WHEN fraude = 1 AND delay_notif_fraude_tag <= 90  THEN amount_usd ELSE 0 END) AS fraude_90dias,
  SUM(CASE WHEN fraude = 1 AND delay_notif_fraude_tag <= 120 THEN amount_usd ELSE 0 END) AS fraude_120dias,

  -- Cantidad de fraudes
  SUM(CASE WHEN fraude = 1 AND delay_notif_fraude_tag <= 30  THEN 1 ELSE 0 END) AS qty_fraude_30dias,
  SUM(CASE WHEN fraude = 1 AND delay_notif_fraude_tag <= 60  THEN 1 ELSE 0 END) AS qty_fraude_60dias,
  SUM(CASE WHEN fraude = 1 AND delay_notif_fraude_tag <= 90  THEN 1 ELSE 0 END) AS qty_fraude_90dias,
  SUM(CASE WHEN fraude = 1 AND delay_notif_fraude_tag <= 120 THEN 1 ELSE 0 END) AS qty_fraude_120dias,

  -- Volúmenes
  SUM(CASE WHEN pay_status_id <> 'rejected' THEN 1 ELSE 0 END) AS qty_tpv,
  SUM(CASE WHEN pay_status_id <> 'rejected' THEN amount_usd ELSE 0 END) AS tpv_total
FROM q_calc
GROUP BY mes
ORDER BY mes;
