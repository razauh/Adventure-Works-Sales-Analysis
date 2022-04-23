use AdventureWorks2019;

--per customer contribution to total revenue

select [CustomerID], [OrderDate],
		count([SalesOrderID]) over (partition by [CustomerID]) as TotalOrdersByCustomer,
		format(sum([SubTotal]) over (partition by [CustomerID]), 'C2') as RevenuePerCustomer,
		format(sum([SubTotal]) over(), 'C2') as TotalRevenue,
		format((sum([SubTotal]) over (partition by [CustomerID])) / (sum([SubTotal]) over()), 'P2') as CustomerRevenueRatio
into #CustomerTemp
FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]
order by [CustomerID] desc;

select *, 
	row_number() over ( partition by [CustomerID] order by TotalOrdersByCustomer desc)  as [row_number] 
into #CustomerTemp2
from #CustomerTemp;

select * 
from #CustomerTemp2
where [row_number] = 1
order by TotalOrdersByCustomer desc;






--monthly and annual sales

with base as
(
	select distinct year([OrderDate]) as [Year],
			month([OrderDate]) as [Month],
			sum([SubTotal]) over (partition by year([OrderDate]), month([OrderDate])) as MonthlySales,
			sum([SubTotal]) over (partition by year([OrderDate])) as AnnualSales
	FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]
)

select [Year], [MONTH],
	FORMAT(MonthlySales, 'C2') as [MonthlySales],
	FORMAT(AnnualSales, 'C2') as [AnunalSales],
	FORMAT([MonthlySales]/[AnnualSales], 'P') AS [% of AnnualSales],
	DENSE_RANK() OVER (PARTITION BY [Year] ORDER BY [MonthlySales]DESC) AS AnnualSales

FROM base
ORDER BY [Year], [Month];  



--the most profitable months

with base as
(
	select distinct year([OrderDate]) as [Year],
			month([OrderDate]) as [Month],
			sum([SubTotal]) over (partition by year([OrderDate]), month([OrderDate])) as MonthlySales,
			sum([SubTotal]) over (partition by year([OrderDate])) as AnnualSales
	FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]

),
YearlySales AS
(
	select [Year], [MONTH],
		FORMAT(MonthlySales, 'C2') as [MonthlySales],
		FORMAT(AnnualSales, 'C2') as [AnunalSales],
		FORMAT([MonthlySales]/[AnnualSales], 'P') AS [% of AnnualSales],
		DENSE_RANK() OVER (PARTITION BY [Year] ORDER BY [MonthlySales]DESC) AS MonthlyRank
	FROM base
)
SELECT [Year], [MONTH], [MonthlySales], [AnunalSales], [% of AnnualSales]
FROM YearlySales
WHERE MonthlyRank = 1
ORDER BY [Year];


--Running total

with AnnualRevenue as
(
	select year(OrderDate) as [Year],
		sum([SubTotal]) as TotalRevenue
	from [AdventureWorks2019].[Sales].[SalesOrderHeader]
	group by year(OrderDate)
)
select [Year],
	format(TotalRevenue, 'C2') as Reveue,
	format(sum(TotalRevenue) over (order by [year] asc 
		range between unbounded preceding and current row), 'C2') as RunningTotal
from AnnualRevenue;



--expected revenue over the years based on previous two years

with AnnualRevenue as
(
	select year(OrderDate) as [Year],
		sum([SubTotal]) as TotalRevenue
	from [AdventureWorks2019].[Sales].[SalesOrderHeader]
	group by year(OrderDate)
), 
ExpectedRevenue as
(
	select [Year], TotalRevenue,
		avg(TotalRevenue) over (order by [Year] rows between 3 preceding and 1 preceding) as ExpectedRevenue
	from AnnualRevenue
)
select [Year], TotalRevenue, ExpectedRevenue,
	(TotalRevenue - ExpectedRevenue) / ExpectedRevenue as [% variance]
from ExpectedRevenue;




-- product performance as compared to sub category and category


with ProductSales as
(
	select distinct x.ProductID, x.SubCatID, x.ProdCatID,
		sum(y.[LineTotal]) over (partition by y.ProductID) as ProductRevenue
	from (
		select p.[ProductID] as ProductID, ps.[ProductSubcategoryID] as SubCatID, ps.[ProductCategoryID] as ProdCatID
		from [AdventureWorks2019].[Production].[Product] p
		inner join [AdventureWorks2019].[Production].[ProductSubcategory] ps
		on p.[ProductSubcategoryID] = ps.[ProductSubcategoryID]
	) x
		join 
	(
		select [ProductID], [LineTotal] from [AdventureWorks2019].[Sales].[SalesOrderDetail]
	)y
	on x.ProductID = y.ProductID
)
select ProductID, 
	format(ProductRevenue,'C2') as ProductRevenue,
	format(ProductRevenue / sum(ProductRevenue) over (partition by SubCatID),'P') as ComparedToSubCategory,
	format(ProductRevenue / sum(ProductRevenue) over (partition by ProdCatID),'P') as ComparedToCategory
from ProductSales
order by ProdCatID, SubCatID;


--yearly products sales

select 
--	sh.[SubTotal] as SubTotal, 
	sd.[ProductID] as ProductID, 
	year(sh.[OrderDate]) as [Year],
	UnitPrice,
	sum(OrderQty) over (partition by sd.[ProductID], year(sh.[OrderDate])) as ProductsCount,
	sum((OrderQty * UnitPrice)) over (partition by sd.[ProductID], year(sh.[OrderDate])) as YearlyRevenue
into #YearlyRevenueTemp2
from [AdventureWorks2019].[Sales].[SalesOrderHeader] sh
inner join [AdventureWorks2019].[Sales].[SalesOrderDetail] sd
on sh.[SalesOrderID] = sd.[SalesOrderID];

select ProductID,  [Year] , 
	ProductsCount,
	UnitPrice as SalePrice,
	format(YearlyRevenue, 'C2') AS YearlyRevenue,
	row_number() over ( partition by [Year], ProductID order by ProductID desc)  as [row_number] 
into #temp4
from #YearlyRevenueTemp2;

select * from #temp4 where [row_number] = 1 order by ProductID asc;


--yearly cost analysis per product

select 
	ProductID, year(DueDate) as [Year],
	UnitPrice,
	sum(StockedQty) over (partition by ProductID,  year(DueDate)) as NumberOfProducts,
	sum((UnitPrice * StockedQty)) over (partition by ProductID, year(DueDate)) as YearlyCost
into #CostTemp2
from [AdventureWorks2019].[Purchasing].[PurchaseOrderDetail];

select ProductID, [Year], 
	UnitPrice,
	NumberOfProducts,
	format(YearlyCost, 'C2') as YearlyCost,
	ROW_NUMBER() over (partition by [Year], ProductID order by productID) as [row_number]
into #CostTemp3
from #CostTemp2;

select * from #CostTemp3 where [row_number] = 1 order by ProductID asc;


----------------------------------------------------------------------
--calculate revenue
select 
--	sh.[SubTotal] as SubTotal, 
	sd.[ProductID] as ProductID, 
	year(sh.[OrderDate]) as [Year],
	UnitPrice,
	sum(OrderQty) over (partition by sd.[ProductID], year(sh.[OrderDate])) as ProductsCount,
	sum((OrderQty * UnitPrice)) over (partition by sd.[ProductID], year(sh.[OrderDate])) as YearlyRevenue
into #YearlyRevenueTemp2
from [AdventureWorks2019].[Sales].[SalesOrderHeader] sh
inner join [AdventureWorks2019].[Sales].[SalesOrderDetail] sd
on sh.[SalesOrderID] = sd.[SalesOrderID];

select ProductID,  [Year] , 
	ProductsCount,
	UnitPrice as SalePrice,
	format(YearlyRevenue, 'C2') AS YearlyRevenue,
	row_number() over ( partition by [Year], ProductID order by ProductID desc)  as [row_number] 
into #temp4
from #YearlyRevenueTemp2;

--calculate cost
select ProductID, year(DueDate) as [Year],
	UnitPrice,
	sum(StockedQty) over (partition by ProductID,  year(DueDate)) as NumberOfProducts,
	sum((UnitPrice * StockedQty)) over (partition by ProductID, year(DueDate)) as YearlyCost
into #CostTemp2
from [AdventureWorks2019].[Purchasing].[PurchaseOrderDetail];

select ProductID, [Year], 
	UnitPrice,
	NumberOfProducts,
	format(YearlyCost, 'C2') as YearlyCost,
	ROW_NUMBER() over (partition by [Year], ProductID order by productID) as [row_number]
into #CostTemp3
from #CostTemp2;


--profit analysis
-- the problem here is that dataset is very inconsistant as products are sold before purchasing
select 
	revenue.ProductID,
	revenue.[Year],
	cost.UnitPrice as PurchasePrice,
	revenue.SalePrice as SalePrice,
	(cost.UnitPrice * revenue.ProductsCount) as YearlyProductsCost,
	revenue.YearlyRevenue,
	revenue.YearlyRevenue - (cost.UnitPrice * revenue.ProductsCount) as Profit
from (
	select * from #temp4 where [row_number] = 1 
	) revenue
join (
	select * from #CostTemp3 where [row_number] = 1 
	) cost
on revenue.ProductID = cost.ProductID
where revenue.ProductID = cost.ProductID 
--AND revenue.[Year] = cost.[Year]  
order by revenue.[Year], cost.[Year];





--territory analysis

with TerritorySales as
(
select [TerritoryID], 
		count([SalesOrderID]) over (partition by [TerritoryID]) as TotalOrdersByTerritory,
		format(sum([SubTotal]) over (partition by [TerritoryID]), 'C2') as RevenuePerTerritory,
		format(sum([SubTotal]) over(), 'C2') as TotalRevenue,
		format((sum([SubTotal]) over (partition by [TerritoryID])) / (sum([SubTotal]) over()), 'P2') as CustomerRevenueRatio
FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]

)
select distinct *
from TerritorySales;


--yearly territory analysis

select [TerritoryID], year([OrderDate]) as [Year],
		count([SalesOrderID]) over (partition by  year([OrderDate]), [TerritoryID]) as OrderCountOverTheYears,
		format(sum([SubTotal]) over 
			(partition by  year([OrderDate]), [TerritoryID]), 'C2') as RevenueOverTheYears,
		format((sum([SubTotal]) over 
			(partition by  year([OrderDate]), [TerritoryID])) / 
			(sum([SubTotal]) over (partition by [TerritoryID])), 'P2') as [% of Total Territory Revenue]
into #TerritoryTemp
FROM [AdventureWorks2019].[Sales].[SalesOrderHeader];

select *,
	row_number() over ( partition by [Year], [TerritoryID] order by [TerritoryID] desc)  as [row_number] 
into #TerritoryTemp2
from #TerritoryTemp;

select * 
from #TerritoryTemp2
where [row_number] = 1
order by [TerritoryID];


--order pair analysis

with orderParis  as
(
	select CONCAT(tb1.ProductID, ',', tb2.ProductID) as items, tb1.OrderDate
	from (
			select sh.[OrderDate] as OrderDate, sd.[ProductID] as ProductID
			from [AdventureWorks2019].[Sales].[SalesOrderHeader] sh
			inner join [AdventureWorks2019].[Sales].[SalesOrderDetail] sd
			on sh.[SalesOrderID] = sd.[SalesOrderID]
			) tb1
	join (
			select sh.[OrderDate] as OrderDate, sd.[ProductID] as ProductID
			from [AdventureWorks2019].[Sales].[SalesOrderHeader] sh
			inner join [AdventureWorks2019].[Sales].[SalesOrderDetail] sd
			on sh.[SalesOrderID] = sd.[SalesOrderID]) tb2
	on (tb1.OrderDate = tb2.OrderDate and
		tb1.ProductID != tb2.ProductID and
		tb1.ProductID < tb2.ProductID
		)
)
select items, count(*) as frequency
from orderParis
group by items
order by items;


--sum of orders per month each year 

select 
	month([OrderDate]) as [month],
	format(sum(case when year([OrderDate]) = 2011 then [SubTotal] end), 'C2') as r2011,
	format(sum(case when year([OrderDate]) = 2012 then [SubTotal] end), 'C2') as r2012,
	format(sum(case when year([OrderDate]) = 2013 then [SubTotal] end), 'C2') as r2013,
	format(sum(case when year([OrderDate]) = 2014 then [SubTotal] end), 'C2') as r2014
	
FROM [AdventureWorks2019].[Sales].[SalesOrderHeader]
group by month([OrderDate])
order by month([OrderDate]);



--sales reasons analysis

select sr.[SalesReasonID], 
	format(sum(sh.[SubTotal]), 'C2')
from [AdventureWorks2019].[Sales].[SalesOrderHeaderSalesReason] sr
inner join [AdventureWorks2019].[Sales].[SalesOrderHeader] sh
on sr.[SalesOrderID] = sh.[SalesOrderID]
group by sr.[SalesReasonID]
order by sr.[SalesReasonID];


--over the years

select sr.[SalesReasonID], year(sh.[OrderDate]) as [Year],
	count(sh.[SalesOrderID]) over(partition by year(sh.[OrderDate]), sr.[SalesReasonID]) as OrderCountOverTheYears,
	format(sum(sh.[SubTotal]) over(partition by year(sh.[OrderDate]), sr.[SalesReasonID]), 'C2') as RevenueOverTheYears,
	format(sum(sh.[SubTotal]) over(partition by year(sh.[OrderDate]), sr.[SalesReasonID]) /
		(sum([SubTotal]) over (partition by sr.[SalesReasonID])), 'P2') as [% of Total Reason Revenue]
into #ReasonTemp1
from [AdventureWorks2019].[Sales].[SalesOrderHeaderSalesReason] sr
inner join [AdventureWorks2019].[Sales].[SalesOrderHeader] sh
on sr.[SalesOrderID] = sh.[SalesOrderID]

order by sr.[SalesReasonID]

select *,
	row_number() over ( partition by [Year], [SalesReasonID] order by [SalesReasonID] desc)  as [row_number] 
into #ReasonTemp2
from #ReasonTemp1;

select * 
from #ReasonTemp2
where [row_number] = 1
order by [SalesReasonID];



--calculate median values of products
with RankedTable as
(
	select 
		ProductID,
		UnitPrice,
		ROW_NUMBER() OVER (PARTITION BY ProductID ORDER BY UnitPrice) AS Rnk,
		COUNT(*) OVER (PARTITION BY ProductID) AS Cnt
	from [AdventureWorks2019].[Sales].[SalesOrderDetail] 
)
select
	ProductID,
	UnitPrice
into #ProductMedians
FROM RankedTable
WHERE Rnk = Cnt / 2 + 1;

--yearly profit


select 
	revenue.[Year], 
	format(cost.TotalCost, 'C2') as cost, 
	format(revenue.TotalRevenue, 'C2') as revenue,
	format((revenue.TotalRevenue - cost.TotalCost), 'C2') as YearlyProfit
into Profit
from (
	select  
		year(sh.[OrderDate]) as [Year],
		sum(sd.UnitPrice) as TotalRevenue
	from [AdventureWorks2019].[Sales].[SalesOrderHeader] sh
	inner join [AdventureWorks2019].[Sales].[SalesOrderDetail] sd
	on sh.[SalesOrderID] = sd.[SalesOrderID]
	group by year(sh.[OrderDate]) 
	) revenue
join (
	select 
		year(DueDate) as [Year],
		sum(UnitPrice) as TotalCost
	from [AdventureWorks2019].[Purchasing].[PurchaseOrderDetail]
	group by year(DueDate)
	) cost
on revenue.[Year] = cost.[Year]



