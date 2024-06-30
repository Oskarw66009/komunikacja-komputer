	 DECLARE
     @DataStart TSLDateTime,
     @DataStop TSLDateTime,
     @DataStartOld TSLDateTime,
     @DataStopOld TSLDateTime,
     @Srednica varchar(30);
	 
     SELECT
     @DataStart = '2023-01-01',
     @DataStop = '2023-06-30',
	 @DataStartOld = '2022-01-01',
	 @DataStopOld = '2022-06-30',
     @Srednica = '170';
 
	 BEGIN
-- Podzapytanie obliczaj¹ce sumê opon dla pierwszego zakresu dat grupowane wed³ug kontrahenta SaldoWn = SaldoMa
 WITH 
	MAB2B AS (
	SELECT * FROM dbo.wusr_vv_WartosciSprzedazyIMarzHandlowe k
	WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.wusr_vv_DaneInternet di WITH(NOLOCK)
    WHERE di.Logo = k.Logo
)),
	/*MAB2B AS (
    SELECT DISTINCT Login
    FROM dbo.wusr_vv_DaneInternet  --<-- Wersja z warunkiem pocz¹tkowym choæ nie wiem czy jest potrzebna ;-;
    WHERE Login IS NOT NULL
	), */
	SumaOpon AS (
    SELECT
        a.NIPSameCyfry,
        SUM(a.Ilosc) AS suma1biezacy
    FROM
        dbo.wusr_vv_WartosciSprzedazyIMarzHandlowe a
    WHERE
        LEFT(a.SymKar,2) IN ('BR','BF','CC','CU','CB','MA','GG','GD','GF','GN','MN','HT')
		AND (a.PD_Typ_SerwisOsob = 1 OR a.PD_Typ_SerwisTir = 1 OR a.PD_Typ_Warsztat = 1)
        AND a.Symkar LIKE '__[ODT][LZW]%'
        AND a.SymRej LIKE 'SPRZ\H%'
        AND a.wusr_grupa LIKE 'KT\Opon%'
        AND a.Data BETWEEN @DataStart AND @DataStop
		AND a.Zaplacone = 1

    GROUP BY
        a.NIPSameCyfry

),
-- Podzapytanie obliczaj¹ce sumê opon dla drugiego zakresu dat grupowane wed³ug kontrahenta
SumaOpon2 AS (
    SELECT
        a.NIPSameCyfry,
        SUM(a.Ilosc) AS suma2stary
    FROM
        dbo.wusr_vv_WartosciSprzedazyIMarzHandlowe a
    WHERE
        LEFT(a.SymKar,2) IN ('BR','BF','CC','CU','CB','MA','GG','GD','GF','GN','MN','HT')
		AND (a.PD_Typ_SerwisOsob = 1 OR a.PD_Typ_SerwisTir = 1 OR a.PD_Typ_Warsztat = 1)
        AND a.Symkar LIKE '__[ODT][LZW]%'
        AND a.SymRej LIKE 'SPRZ\H%'
        AND a.wusr_grupa LIKE 'KT\Opon%'
        AND a.Data BETWEEN @DataStartOld AND @DataStopOld
		AND a.Zaplacone = 1
		
    GROUP BY
        a.NIPSameCyfry

),
MIN170PLUS AS (
	SELECT 
		a.NIPSameCyfry,
		SUM(a.Ilosc) AS min170plus
		FROM dbo.wusr_vv_WartosciSprzedazyIMarzHandlowe a
		WHERE
		LEFT(a.SymKar,2) IN ('BR','BF','CC','CU','CB','MA','GG','GD','GF','GN','MN','HT')
        AND a.Symkar LIKE '__[ODT][LZW]%'
		AND (a.PD_Typ_SerwisOsob = 1 OR a.PD_Typ_SerwisTir = 1 OR a.PD_Typ_Warsztat = 1)
        AND a.SymRej LIKE 'SPRZ\H%'
        AND a.wusr_grupa LIKE 'KT\Opon%'
        AND a.Data BETWEEN @DataStart AND @DataStop
        AND a.Prm_Srednica >= @Srednica
		AND a.Zaplacone = 1 

		GROUP BY a.NipSameCyfry
)
-- G³ówne zapytanie obliczaj¹ce procentow¹ ró¿nicê dla ka¿dego kontrahenta
SELECT
    COALESCE(SumaOpon.NIPSameCyfry, SumaOpon2.NIPSameCyfry) AS NIPSameCyfry,
    SumaOpon.suma1biezacy, 
    SumaOpon2.suma2stary, 
	MIN170PLUS.min170plus,
    CASE
		WHEN SumaOpon.suma1biezacy >= suma2stary 
		AND (CAST(MIN170PLUS.min170plus AS FLOAT) / SumaOpon.suma1biezacy) > 0.25 THEN 'TAK'
        ELSE 'NIE'
    END AS CZY_UDZIAL
FROM
    SumaOpon
INNER JOIN
    SumaOpon2 ON SumaOpon.NIPSameCyfry = SumaOpon2.NIPSameCyfry 
LEFT JOIN MIN170PLUS ON SumaOpon.NIPSameCyfry = MIN170PLUS.NIPSameCyfry
WHERE 
    SumaOpon.suma1biezacy IS NOT NULL
    AND SumaOpon2.suma2stary IS NOT NULL
	AND MIN170PLUS.min170plus IS NOT NULL
	AND SumaOpon.suma1biezacy >= 20
	AND SumaOpon2.suma2stary >= 20
	
	ORDER BY CZY_UDZIAL DESC;
	END;