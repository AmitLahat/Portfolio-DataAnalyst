/* Amit Lahat - Course Project, SQL, Data: AdventureWorks2019  */
use AdventureWorks2019

--1: Present data of products that are missing from the orders table.
select productid, name, Color, ListPrice, Size
from production.product
except
select s.productid, p.Name, p.Color, p.ListPrice, p.Size
from sales.salesorderdetail s join production.product p
on s.ProductID=p.ProductID
--
/* run the following before the following exercises:
update sales.customer set personid=customerid where customerid <=290  
update sales.customer set personid=customerid+1700 where customerid >= 300 and customerid<=350  
update sales.customer set personid=customerid+1700 where customerid >= 352 and customerid<=701 
*/
--2: Present data of customers that have no orders.
With CteEx2 as
(select  c.customerid, COALESCE(p.lastname,p.firstname,'Unknown') as 'Last Name',
COALESCE(p.firstname,'Unknown') as 'First Name' 
from sales.customer c left join person.person p 
on c.PersonID=p.BusinessEntityID
except
select c.customerid, COALESCE(p.lastname,'Unknown') as 'Last Name',COALESCE(p.firstname,'Unknown') as 'First Name' 
from sales.customer c left join person.person p 
on c.PersonID=p.BusinessEntityID
join sales.salesorderheader s on s.CustomerID=c.CustomerID)
select *
from CteEx2
order by CustomerID
--
--3: Present data of the top 10 customers with most orders, ordered from most to least.
select top 10 s.CustomerID, p.firstname, p.lastname, count(s.SalesOrderID) as CountOfOrders
from sales.salesorderheader s left join sales.customer c
on s.CustomerID=c.CustomerID
left join person.person p on c.PersonID=p.BusinessEntityID
group by s.CustomerID, p.firstname, p.lastname
order by 4 desc
--
--4: Show data of employees, their role and how many employees have the same role.
select p.FirstName, p.LastName, e.jobtitle, e.HireDate, 
count(e.BusinessEntityID) over(partition by e.jobtitle) as CountOfTitle
from humanresources.employee e join person.person p
on e.BusinessEntityID=p.BusinessEntityID
--
--5: For every customer, show the dates of the last order and the one before it.
with CteEx5 as(
select s.SalesOrderID, s.CustomerID ,p.FirstName, p.LastName, s.orderdate,
row_number() over(partition by s.customerid order by s.orderdate desc, s.salesorderid desc) as OrdNum,
Lead(s.orderdate,1) over(partition by s.customerid order by s.orderdate desc) as PreviousOrder
from person.person p right join  sales.customer c
on p.BusinessEntityID=c.PersonID
 join sales.salesorderheader s on c.CustomerID=s.customerID)

select SalesOrderID,CustomerID,LastName,FirstName, OrderDate,PreviousOrder 
from CteEx5
where OrdNum=1  
order by CustomerID
--
--6: Show the most expensive order per year, it's number and customer
with CteEx6 as( 
select *, rank()over(partition by year order by Total desc) as Rnk
from (select distinct od.salesorderid,oh.customerid, year(oh.orderdate) as 'year',
sum(od.linetotal)over(partition by year(oh.orderdate),od.salesorderid) as Total
from sales.salesorderdetail od join sales.salesorderheader oh
on od.SalesOrderID=oh.SalesOrderID) s
)
select YEAR, SalesOrderID,pp.LastName,pp.FirstName, Format(Total,'c','EN-US') as Total
from CteEx6 ct left join sales.Customer sc
on ct.CustomerID=sc.CustomerID
left join person.person pp on pp.BusinessEntityID=sc.PersonID
where Rnk=1
order by year
--
--7: Show the count of orders for each month per year.
select * from(select datepart(yy,orderdate) as year, datepart(mm,orderdate) as Month, SalesOrderID
from sales.salesorderheader) Sct
PIVOT (count(salesorderid) FOR Year in ([2011],[2012],[2013],[2014])) as pvt
order by month
--
--8: Show the order's price sum for every month, add a cumulative column per year and summarizing rows
with CteEx81 as(
select  cast(datepart(yy,oh.orderdate) as varchar(14)) as Year , datepart(mm,oh.orderdate) as Month,
Format(sum(od.linetotal),'c','en-us') as Sum_Price,
Format(sum(sum(od.linetotal))over(partition by datepart(yy,oh.orderdate) order by datepart(mm,oh.orderdate) rows between unbounded preceding and current row),'c','en-us') as money
from sales.salesorderheader oh join sales.SalesOrderDetail od
on oh.SalesOrderID=od.SalesOrderID
group by datepart(yy,oh.orderdate), datepart(mm,oh.orderdate))
,
CteEx82 as(
select  cast(datepart(yy,oh.orderdate) as varchar(14))+' Total:' as Year, NULL as Month, NULL as Sum_Price,
Format(sum(od.linetotal),'c','en-us') as money
from sales.salesorderheader oh join sales.SalesOrderDetail od
on oh.SalesOrderID=od.SalesOrderID
group by datepart(yy,oh.orderdate)
union
select 'Grand_Total' as Year, NULL as Month, NULL as Sum_Price,
format(sum(od.linetotal),'c','en-us') as money
from sales.salesorderheader oh join sales.SalesOrderDetail od
on oh.SalesOrderID=od.SalesOrderID
)
select * from CteEx81 
union
select * from CteEx82
--
--9: Order per department the employees by their seniority (months), add the hire date of the previous employee and date difference (days).
with Cte1 as
( select he.BusinessEntityID as EmployeeID, pp.firstname+' '+pp.lastname as 'Full Name',
  he.HireDate,datediff(mm,he.HireDate,getdate())  as Seniority
  from [Person].[Person] pp join [HumanResources].[Employee] he on he.BusinessEntityID=pp.BusinessEntityID)
,
Cte2 as
( select hd.name as DepartmentName, heh.businessentityid
  from [HumanResources].[EmployeeDepartmentHistory] heh join [HumanResources].[Department] hd
  on hd.DepartmentID=heh.DepartmentID
  where heh.enddate is null
)
 select DepartmentName,EmployeeID, [Full Name], HireDate, Seniority, 
 Lead([FUll Name],1)over(partition by DepartmentName order by HireDate desc) as PreviousEmpName,
 Lead(HireDate,1)over(partition by DepartmentName order by HireDate desc) as PreviousEmpHDate,
 datediff(dd,Lead(HireDate,1)over(partition by DepartmentName order by HireDate desc),HireDate) as DiffDays
 from Cte2 join Cte1 on cte1.EmployeeID=Cte2.BusinessEntityID
 --
 --10: By department and by date, string together details of employees who were hired together.
with CteEx10 as
(select he.HireDate, heh.DepartmentID, concat(he.BusinessEntityID,' ',pp.LastName,' ',pp.FirstName) as Employee_Info
from [Person].[Person] pp
join [HumanResources].[Employee] he on pp.BusinessEntityID=he.BusinessEntityID
join [HumanResources].[EmployeeDepartmentHistory] heh on heh.BusinessEntityID=pp.BusinessEntityID
join [HumanResources].[Department] hd on hd.DepartmentID=heh.DepartmentID
where heh.enddate is null
)
select HireDate, DepartmentID, 
STRING_AGG(Employee_Info,', ') as Employees_Info
from CteEx10
group by hiredate, departmentid
order by HireDate
-- 