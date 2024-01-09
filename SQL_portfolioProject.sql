--Analysing ETF prices. The data is obtained from Kaggle.
#
-- Explore the database
Select * From INFORMATION_SCHEMA.TABLES
Select * From sys.all_columns

--. Delete a Table from the database
Drop Table ETFs_1;
DROP View VW_ETF_5Year_Prices;


-- Rename a table, and columns
EXEC sp_rename ETFs_1, ETFs
EXEC sp_rename [ETF prices].close, [ETF prices].closePrice;

--Change the datatype of date from varchar to date
Select * 
	From INFORMATION_SCHEMA.COLUMNS
Where 
	TABLE_NAME = 'ETF prices';

Alter table [ETF prices]
Alter Column price_date Date;

--Join ETF and ETF prices table

Select * 
	From ETFs e
Join 
	[ETF prices] ep 
ON 
	e.fund_symbol = ep.fund_symbol

--Join relevant columns only

Select 
	e.fund_symbol, e.region, e.currency, e.fund_category, e.investment_strategy, e.investment_type, e.inception_date,
	ep.price_date, ep.openPrice, ep.high, ep.low, ep.closePrice, ep.adj_close, ep.volume
From 
	ETFs e
Join 
	[ETF prices] ep 
ON 
	e.fund_symbol=ep.fund_symbol


-- Create a view from the joined tables and selected columns and just look at the latest 3 years price data

CREATE VIEW 
	VW_ETF_5Year_Prices AS
Select 
	e.fund_symbol, e.region, e.currency, e.fund_category, e.investment_strategy, e.investment_type, e.inception_date,
	ep.price_date, ep.openPrice, ep.high, ep.low, ep.closePrice, ep.adj_close, ep.volume
From 
	ETFs e
Join 
	[ETF prices] ep 
ON 
	e.fund_symbol=ep.fund_symbol
Where 
	ep.price_date >= '2017-01-01';

--3 years
CREATE VIEW 
	VW_ETF_3Year_Prices AS
Select 
	e.fund_symbol, e.region, e.currency, e.fund_category, e.investment_strategy, e.investment_type, e.inception_date,
	ep.price_date, ep.openPrice, ep.high, ep.low, ep.closePrice, ep.adj_close, ep.volume
From 
	ETFs e
Join 
	[ETF prices] ep 
ON 
	e.fund_symbol=ep.fund_symbol
Where 
	ep.price_date >= '2019-01-01';

--1 year
CREATE VIEW 
	VW_ETF_1Year_Prices AS
Select 
	e.fund_symbol, e.region, e.currency, e.fund_category, e.investment_strategy, e.investment_type, e.inception_date,
	ep.price_date, ep.openPrice, ep.high, ep.low, ep.closePrice, ep.adj_close, ep.volume
From 
	ETFs e
Join 
	[ETF prices] ep 
ON 
	e.fund_symbol=ep.fund_symbol
Where 
	ep.price_date >= '2021-01-01';


CREATE VIEW 
	VW_ETF_1Year_Prices AS -- add fund name and fund family
Select 
	e.fund_symbol, e.fund_long_name , e.fund_family, e.region, e.currency, e.fund_category, e.investment_strategy, e.investment_type, e.inception_date,
	ep.price_date, ep.openPrice, ep.high, ep.low, ep.closePrice, ep.adj_close, ep.volume
From 
	ETFs e
Join 
	[ETF prices] ep 
ON 
	e.fund_symbol=ep.fund_symbol
Where 
	ep.price_date >= '2021-01-01';

-- check the view table
Select * From VW_ETF_1Year_Prices
Order By price_date ASC

--over the last five years which top-10 funds traded the most
Select Top 10 fund_symbol, sum(volume) From VW_ETF_5Year_Prices
Group By fund_symbol
Order By fund_symbol desc

--What is the highest traded fund, hence by Volume in the latest 1 year
Select 
	fund_family, fund_category, fund_long_name, fund_symbol, volume 
From 
	VW_ETF_1Year_Prices
Where 
	volume = (Select Max(Volume) From VW_ETF_1Year_Prices) ;

--What is the least traded fund where volume is more than 100
Select 
	fund_family, fund_category, fund_long_name, fund_symbol, volume 
From 
	VW_ETF_1Year_Prices
Where 
	volume = (Select MIN(Volume) From VW_ETF_1Year_Prices Where Volume > 100) ;

--How many funds have been traded in the latest 1 year
Select 
	Count(Distinct fund_symbol) NumberOfFunds 
From 
	VW_ETF_1Year_Prices;

--count how many funds are traded atleast more than a billion times within the latest year
Select 
	count(*) 
From 
	(
Select 
	fund_long_name, sum(volume) volumePerFund From VW_ETF_1Year_Prices
Group By fund_long_name
	) t
Where volumePerFund >= 1000000000

Select * From VW_ETF_1Year_Prices

--What is the median price (open, high, low, closed) per fund in the latest year
Select 
	fund_symbol, percentile_cont(0.5) Within Group (Order By high) Over(Partition By fund_symbol) 
as 
	median_highPrice
From 
	VW_ETF_1Year_Prices;

--The above displays the median for every price data, therefore the same median value is displayed multiple time
--so to get a distinct median value we use ROW_Number and Query within Query or Common Table Ex[ression (CTE)
With t as 
	(
Select 
	fund_symbol, ROW_NUMBER() Over(partition by fund_symbol Order by high) as rn,
	percentile_cont(0.5) Within Group (Order By high) Over(Partition By fund_symbol) median_highPrice
From 
	VW_ETF_1Year_Prices
	)
Select 
	fund_symbol, median_highPrice 
From 
	t
Where 
	rn = 1
Order By median_highPrice;

--Average price per fund

Select 
	fund_symbol, AVG(closePrice) avgClosePrice
From 
	VW_ETF_1Year_Prices 
Group By 
	fund_symbol
Order By 
	avgClosePrice DESC;

--What are Top 10 highest traded funds in the last five years
--First lets order or dense rank by sum of volume per year
With t as 
	(
Select 
	Year(price_date) trading_year, fund_symbol, Sum(volume) volume_per_year 
From 
	VW_ETF_5Year_Prices Group By Year(price_date), fund_symbol 
	)
Select 
	*, Dense_Rank() Over(Partition By trading_year Order By volume_per_year Desc) drn 
From t
Order By trading_year, drn asc 
--Then the Top 10 per year can then be extracted as below
--3. extract the top 10 oer year
with t2 as (
--2. create a dense rank for each volume in descengin order per year
Select 
	*, Dense_Rank() Over(Partition By trading_year Order By volume_per_year Desc) drn 
From 
	( 
--1.first sum the volume per year
	Select 
		Year(price_date) trading_year, fund_symbol, Sum(volume) volume_per_year 
	From 
		VW_ETF_5Year_Prices 
	Group By 
		Year(price_date), fund_symbol 
	) t1
)
Select * From t2 where drn<=10 Order By trading_year, drn asc;

--A short neat way of extracting the data could be achieved as shown below:
with t1 as (--sum the volume, dense rank it by year (partition by year) in descending order
Select Year(price_date) trading_year, 
	   fund_symbol, 
	   Sum(volume) volume_per_year,
	   Dense_Rank() Over(Partition By Year(price_date) Order By Sum(volume) Desc) drn
From VW_ETF_5Year_Prices 
Group By Year(price_date), fund_symbol 
)
Select * From t1 --filter all top 10 per year
Where drn <=10
Order By trading_year 

