UPDATE [PortfolioProject].dbo.CovidDeaths
SET continent = NULL
WHERE continent = '';


SELECT * 
FROM PortfolioProject.dbo.CovidDeaths
-- WHERE continent is not NULL
ORDER By 3,4


--SELECT * 
--FROM PortfolioProject.dbo.CovidVaccinations
--ORDER By 3,4



-- Select Data that we are going to be using
SELECT Location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject.dbo.CovidDeaths
ORDER By 1,2


-- Creating Temp Table to hold converted columns
SELECT 
    CONVERT(date, date, 101) AS ConvertedDate, -- Convert the date
    TRY_CONVERT(decimal, total_cases) AS ConvertedTotalCases, -- Convert total_cases
    TRY_CONVERT(decimal, total_deaths) AS ConvertedTotalDeaths, -- Convert total_deaths
    * -- Include all other columns from the original table
    --Location
INTO #TempCovidDeaths -- Create and insert into temporary table
FROM PortfolioProject.dbo.CovidDeaths;

SELECT Location, ConvertedDate, ConvertedTotalCases, new_cases, ConvertedTotalDeaths, population
FROM #TempCovidDeaths
ORDER By 1,2

UPDATE #TempCovidDeaths
SET continent = NULL
WHERE continent = '';

-- Looking at Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in your country
SELECT Location, ConvertedDate, ConvertedTotalCases, ConvertedTotalDeaths, (ConvertedTotalDeaths/ConvertedTotalCases)*100 as DeathPercentage
FROM #TempCovidDeaths
ORDER BY 
    1, 2;


-- Can also do:
SELECT Location, ConvertedDate, ConvertedTotalCases, ConvertedTotalDeaths, (ConvertedTotalDeaths/ConvertedTotalCases)*100 as DeathPercentage
FROM #TempCovidDeaths
WHERE Location like '%states%'
ORDER BY 1, 2


-- Looking at Total Cases vs Population
-- Shows what percentage of population had Covid
SELECT Location, ConvertedDate, population, ConvertedTotalCases, (ConvertedTotalCases/population)*100 as CovidCasePercentage
FROM #TempCovidDeaths
WHERE Location like '%states%'
ORDER BY 1, 2



-- Looking at Countires with Highest Infection Rate compared to Population

SELECT location, population, MAX(ConvertedTotalCases) as HighestInfectionCount, MAX((ConvertedTotalCases/population))*100 as CovidCasePercentage
FROM #TempCovidDeaths
--Where Location like '%states%'
GROUP BY location, population
ORDER BY CovidCasePercentage desc


-- Showing Countries with the Highest Death Count per Population

SELECT location, MAX(cast(ConvertedTotalDeaths as int)) as TotalDeathCount
FROM #TempCovidDeaths
--Where Location like '%states%'
WHERE continent is not NULL
GROUP BY location
ORDER BY TotalDeathCount desc



-- LET'S BREAK THINGS DOWN BY CONTINENT
-- Correct Way Below for SQL but won't really work for a Drill Down in Tableau/PowerBI
SELECT location, MAX(cast(ConvertedTotalDeaths as int)) as TotalDeathCount
FROM #TempCovidDeaths
--Where Location like '%states%'
WHERE continent is NULL
AND location NOT IN ('High income', 'Upper middle income', 'Lower middle income', 'Low income')
GROUP BY location
ORDER BY TotalDeathCount desc


-- Tableau/Vizualization Version below -> Works for Drill-Downs Better.
SELECT continent, MAX(cast(ConvertedTotalDeaths as int)) as TotalDeathCount
FROM #TempCovidDeaths
WHERE continent is not NULL
GROUP BY continent
ORDER BY TotalDeathCount desc


-- GLOBAL NUMBERS
SELECT 
    ConvertedDate, 
    SUM(CAST(new_cases AS int)) AS total_cases,  -- Convert new_cases to int before summing
    SUM(CAST(new_deaths AS int)) AS total_deaths, -- Convert new_deaths to int before summing
    SUM(CAST(new_deaths AS int)) * 100.0 / NULLIF(SUM(CAST(new_cases AS int)), 0) AS DeathPercentage -- Calculate DeathPercentage
FROM 
    #TempCovidDeaths
WHERE 
    continent IS NOT NULL
GROUP BY 
    ConvertedDate
ORDER BY 
    1,2


-- And this way 
SELECT  
    SUM(CAST(new_cases AS int)) AS total_cases,  -- Convert new_cases to int before summing
    SUM(CAST(new_deaths AS int)) AS total_deaths, -- Convert new_deaths to int before summing
    SUM(CAST(new_deaths AS int)) * 100.0 / NULLIF(SUM(CAST(new_cases AS int)), 0) AS DeathPercentage -- Calculate DeathPercentage
FROM 
    #TempCovidDeaths
WHERE 
    continent IS NOT NULL
ORDER BY 
    1,2



--USING CTE:
WITH PopvsVac (continent, location, date, population, New_Vaccinations, RollingPeopleVaccinated)
as
(
-- Looking at Total Population vs Vaccinations
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(cast(vac.new_vaccinations as bigint)) OVER (Partition by dea.location Order by dea.location, dea.date) as RollingPeopleVaccinated
-- ,(RollingPeopleVaccinated/population)*100
FROM PortfolioProject.dbo.CovidDeaths dea
JOIN PortfolioProject.dbo.CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is not NULL
--ORDER BY 2,3
)

Select *, (CAST(RollingPeopleVaccinated as float)/Population)*100
FROM PopvsVac





-- USING Temp Table
DROP Table if exists #PercentagePopulationVaccinated
INSERT INTO #PercentPopulationVaccinated
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    TRY_CONVERT(numeric, dea.population) AS Population,  -- Convert to numeric
    TRY_CONVERT(numeric, vac.new_vaccinations) AS New_Vaccinations, -- Convert to numeric
    SUM(TRY_CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM 
    PortfolioProject.dbo.CovidDeaths dea
JOIN 
    PortfolioProject.dbo.CovidVaccinations vac
    ON dea.location = vac.location AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL;


Select *, (RollingPeopleVaccinated/population) *100
FROM #PercentPopulationVaccinated





-- Creating View to store data for later visualizations

Create View PercentagePopulationVaccinated as
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    TRY_CONVERT(numeric, dea.population) AS Population,  -- Convert to numeric
    TRY_CONVERT(numeric, vac.new_vaccinations) AS New_Vaccinations, -- Convert to numeric
    SUM(TRY_CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM 
    PortfolioProject.dbo.CovidDeaths dea
JOIN 
    PortfolioProject.dbo.CovidVaccinations vac
    ON dea.location = vac.location AND dea.date = vac.date
WHERE 
    dea.continent IS NOT NULL;


SELECT * 
FROM PortfolioProject.dbo.PercentagePopulationVaccinated
