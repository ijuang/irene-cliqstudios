SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RS_SQ_SalesMonth]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RS_SQ_SalesMonth]
GO


--exec RS_SQ_SalesMonth 2013,11
CREATE    PROCEDURE [dbo].[RS_SQ_SalesMonth] (@Year int=0, @Month int=0) as
/*
Created by:   JGUO 11-15-2008 based on RS_SalesMonth
Modified by: JGUO 12/04/2008 Only include 'sp','co'
		JGUO 08/18/2009	Add Cabinet Count column.
		JGUO 11/10/2009 Modified @lastBusinessDate
		JGUO 03-16-2010 The logic in SQ_SALES should be based on the logic of SQ_SALESYEARMASTER.
		JGUO 10/14/2010 add all size of SEW and SEB into that count
	        JGUO 12/07/2010 Added a new parameter Branch
                ZWANG 12/17/2010 Branch='ALL',shoudl get separate reports on separate pages
                ZWANG 02/10/2011 No filter for branch, just fiscal year and fiscal month.
                Forget build branch, report from revenue branch.  Columns side by side...6SQ, Cliq, Centerpiece, TOTAL.
                Top part is sales dollars, bottom part is cabinets.
                ZWANG 02/28/2012 It appears that the 2011 (prior year) totals are incorrect.Cliq totals may actually be Centerpiece totals, and Cliq totals may not appear at all.
		JGUO 09/08/2013 Add 'SO' Type into it.
                ZWANG 11/19/2013 Add 'XX' type into it.
Requested by: KMS
Purpose:  
Business definitions:

declare @Year as int
declare @Month as int
declare @Branch as int
set @Year = 2010
set @Month = 11
set @Branch = 5200
*/
declare @portionOfMonth as decimal(9,8)
set @portionOfMonth = 1.0
declare @daysInMonth as int, @currentBusinessDay as int
declare @CurrentYear as int,@CurrentMonth as int
declare @lastBusinessDate as datetime
declare @StaDate as datetime,@EndDate as datetime
declare @LyStaDate as datetime,@LyEndDate as datetime
declare @businessDaysComplete as int
--get the last business date
--set @lastBusinessDate = (select max(date) from metadates (nolock) where date <= dbo.datenotime(getdate()-1) and isbusinessday = 1)--Comment by JGUO 11/10/2009
--set @lastBusinessDate = (select max(date) from metadates (nolock) where date <= dbo.datenotime(getdate()) and isbusinessday = 1)--Add by JGUO 11/10/2009
set @lastBusinessDate = (select max(date) from metadates (nolock) where date <= dbo.datenotime(getdate()-1) and isbusinessday = 1)--01/18/2012:Changed by Jeelani per instructions by Jack. The original behavior is right and per Jack there were no requests made to modify that behavior. Please don't revert back the logic.
set @CurrentYear = (select fiscyear from metadates where date = @lastBusinessDate)
set @CurrentMonth = (select fiscmonth from metadates where date = @lastBusinessDate)
--set fiscal year, month
if ((@year = 0) or (@CurrentYear=@year and @CurrentMonth= @month)) begin
   set @year = (select fiscyear from metadates where date = @lastBusinessDate)
   set @month = (select fiscmonth from metadates where date = @lastBusinessDate)
   set @currentBusinessDay = (select BusinessDayOfMonth from metadates where date = @lastBusinessDate)	
   set @daysInMonth = (select max(BusinessDayOfMonth) from metadates where fiscyear = @year and fiscmonth = @month and isbusinessday = 1 )
   set @portionOfMonth = convert(decimal, @currentBusinessDay) / convert(decimal, @daysInMonth)
end
else begin 
   set @daysInMonth = (select max(BusinessDayOfMonth) from metadates where fiscyear = @year and fiscmonth = @month)
   set @currentBusinessDay = @DaysInMonth
end
set @StaDate = (select min(date) from metadates (NOLOCK) where fiscmonth = @Month and fiscyear = @year )
set @EndDate = (select max(date) from metadates (NOLOCK) where fiscmonth = @Month and fiscyear = @year )
----
set @businessDaysComplete = (select max(BusinessDayOfMonth) from metadates (NOLOCK) where fiscmonth = @Month and fiscyear = @year and date<=@LastBusinessDate)
set @LyStaDate = (select min(date) from metadates (NOLOCK) where fiscmonth = @Month and fiscyear = @year-1 )
set @LyEndDate = (select max(date) from metadates (NOLOCK) where fiscmonth = @Month and fiscyear = @year-1 )
---Added by ZWANG 12-17-2010(Begin)--Commented by ZWNAG 02/10/2011
---select branch, mainWarehouse as warehouse ,BranchCode
---into #BranchesTemp
---from branches
---where (@branch=0 OR @Branch=Branch) and Branch>=5000
---Added by ZWANG 12-17-2010(End)--Commented by ZWNAG 02/10/2011
select InvoiceDate
	, @year as InvoiceFiscalYear 	
	, @month as InvoiceFiscalMonth	
	, d.dayofyear as InvoiceDayOfYear 	
	, d.businessday as InvoiceBusinessDay
	---, salesrep				
	, b.Branch
	, b.BranchCode	
	, sum(sales) as Sales
into #Kj1		
from (select Branch,InvoiceDate,Ordernumber,
	sum(sales) as Sales
	from SalesDetails
	where ---OrderStatusCode>=620 and 
        LastStatusCode<>'980' --CountsForRevenue <> 0 JGUO 03/16/2010
	and invoiceDate between @StaDate and @EndDate
	and JDEOrderType in('sp','co','SO','XX')--Add 'so' by JGUO 08/09/2013--Add by JGUO 12/04/2008 Only include 'sp','co'
	group by InvoiceDate, branch, orderNumber)a
join branches b (nolock) on a.branch=b.branch
---left join salesreps c (nolock) on a.salesrep=c.salesreptrend or a.salesrep = c.SalesRepJde
left join metadates d on d.Date = a.InvoiceDate 
 where invoiceDate between @StaDate and @EndDate
       ----and a.branch in( select branch from #BranchesTemp) ---Added by ZWANG 12/17/2010
  --- and (@Branch=0 or a.Branch=@Branch)--Add by JGUO 12/07/2010--Commented by ZWNAG 02/10/2011
 group by InvoiceDate,d.dayofyear,d.businessday
	, b.Branch
	, b.BranchCode
	
	
select invoicedate
	, branch
	, BranchCode  ---Added by ZWANG 12/17/2010
	, sum(sales) as Sales
  into #tempSalesDaily
  from #kj1
  group by invoicedate,branch, BranchCode 

--Add By JGUO 08/18/2009
--Get Cab Qty
select invoicedate 	
        , branch
	,sum(Quantity) as CabQty
into #TempCabDaily1--Modified by JGUO 10/14/2010 #TempCabDaily
from SalesDetails a (nolock)
where invoiceDate between @StaDate and @EndDate
	---and (((Item like '%-BK%' or Item like '%-MI')
	---and JDEOrderType in('sp','co'))
	---or (
        and a.JdeOrderType in ('SO','XX')--Add by JGUO 08/09/2013
        and (a.Item in (select ItemNumber from ItemsCabinetCounts) and a.Linetype='W')---))--Add by JGUO 08/09/2013
        ---and a.branch in( select branch from #BranchesTemp) ---Added by ZWANG 12/17/2010--Commented by ZWNAG 02/10/2011
        ---and (@Branch=0 or a.Branch=@Branch)--Add by JGUO 12/07/2010
group by invoicedate,branch	
--Add end

--Add by JGUO 10/14/2010
insert into #TempCabDaily1
select a.invoicedate 	
        , a.branch
	,sum(a.Quantity) as CabQty
from SalesDetails a (nolock)
join SalesDetails c (nolock) on a.OrderNumber=c.OrderNumber and (a.line/1000)*1000=c.line and a.line<>c.line
where a.invoiceDate between @StaDate and @EndDate
	and (a.Item like '%SEW%' or a.Item like '%SEB%' or a.Item like '%-BK%' or a.Item like '%-MI' )
	and a.JDEOrderType in('SP','CO','SO','XX') and C.linetype<>'W'
        ---and (@Branch=0 or a.Branch=@Branch)--Add by JGUO 12/07/2010--Commented by ZWNAG 02/10/2011
group by a.invoicedate,a.branch	

select invoicedate 	
        , branch
	,sum(CabQty) as CabQty
into #TempCabDaily
from #TempCabDaily1
group by invoicedate,branch	
--Add end

--converts rows to columns
select d.date
	, d.fiscyear
	, d.fiscmonth
       ----, b.Branch
	---, b.BranchCode
	, @portionOfMonth as PortionOfMonth
	, convert(decimal(19,2),0)   as sales5000
	, 0 as CabQty5000--Add By JGUO 08/18/2009 
        , convert(decimal(19,2),0)   as sales5000_LY
	, 0 as CabQty5000_LY--Add By JGUO 08/18/2009
        , convert(decimal(19,2),0)   as sales5200 --Added Cliq 02/10/2011
	, 0 as CabQty5200
        , convert(decimal(19,2),0)   as sales5200_LY --Added Cliq 02/10/2011
	, 0 as CabQty5200_LY
        , convert(decimal(19,2),0)   as sales5300 --Added Cent 02/10/2011
	, 0 as CabQty5300
        , convert(decimal(19,2),0)   as sales5300_LY --Added Cent 02/10/2011
	, 0 as CabQty5300_LY 
	into #temp1
  from metadates d (nolock)
 --- join #BranchesTemp B on (1=1)
-- where fiscyear = @Year and fiscmonth = @Month and d.date <= GetDate()-1--Comment by JGUO 11/10/2009
-- where fiscyear = @Year and fiscmonth = @Month and d.date <= GetDate()--Add by JGUO 11/10/2009
   where fiscyear = @Year and fiscmonth = @Month and d.date <= GetDate()-1--01/18/2012:Changed by Jeelani per instructions by Jack. The original behavior is right and per Jack there were no requests made to modify that behavior. Please don't revert back the logic.

update #temp1 
set sales5000 = s.sales
from #tempSalesDaily s	
where date=s.invoicedate and s.branch=5000

update #temp1 
set CabQty5000 = s.CabQty
from #TempCabDaily s	
where date=s.invoicedate and s.branch=5000
---Added by ZWANG for Cliq 02/10/2011
update #temp1 
set sales5200 = s.sales
from #tempSalesDaily s	
where date=s.invoicedate  and s.branch=5200

update #temp1 
set CabQty5200 = s.CabQty	
from #TempCabDaily s	
where date=s.invoicedate  and s.branch=5200
---Added by ZWANG for Cent 02/10/2011
update #temp1 
set sales5300 = s.sales
from #tempSalesDaily s	
where date=s.invoicedate  and s.branch=5300

update #temp1 
set CabQty5300 = s.CabQty	
from #TempCabDaily s	
where date=s.invoicedate  and s.branch=5300


-------------------------------
---Get Last fiscal year Data(Begin)----
select  Branch --Comment by JGUO 12/07/2010
	---,invoiceDate
	, @year-1 as fiscyear
	, @month as fiscmonth
	, max(m.BusinessDayOfMonth) as BusinessDays
	, sum(sales) as SalesMtd
into #tempLY
from SalesDetails
left join metadates  m (NOLOCK) on date=invoiceDate
where invoiceDate between @LyStaDate and @LyEndDate
and JDEOrderType in('sp','co','SO','XX')--Add 'so' by JGUO 08/09/2013
and m.BusinessDayOfMonth <= @businessDaysComplete
---and branch in(select branch from #BranchesTemp) ---Added by ZWANG 12/17/2010--Commented by ZWNAG 02/10/2011
   --and (@Branch=0 or Branch=@Branch)--Add by JGUO 12/07/2010
group by  branch---,@year-1,@Month

--Add By JGUO 08/18/2009
--Get Cab Qty
--select @year as fiscyear Comment by JGUO 11/10/2009 Fix a bug, last year cab qty. 
select @year-1 as fiscyear --Add by JGUO 11/10/2009
	, @month as fiscmonth		
        , a.branch 
	,sum(Quantity) as CabQty
into #TempCabLY--Modified by JGUO 10/114/2010 #TempCab1
from SalesDetails a (nolock)
left join metadates  m (NOLOCK) on date=invoiceDate
where invoiceDate between @LyStaDate and @LyEndDate
	---and (((Item like '%-BK%' or Item like '%-MI')
	---and JDEOrderType in('sp','co'))
	---or (
        and a.JdeOrderType in ('SO','XX')--Add by JGUO 08/09/2013
        and (a.Item in (select ItemNumber from ItemsCabinetCounts) and a.Linetype='W')---))--Add by JGUO 08/09/2013
	and m.BusinessDayOfMonth <= @businessDaysComplete
       --- and a.branch in(select branch from #BranchesTemp) ---Added by ZWANG 12/17/2010
   ---and (@Branch=0 or a.Branch=@Branch)--Add by JGUO 12/07/2010--Commented by ZWNAG 02/10/2011
group by a.branch --Comment by JGUO 12/07/2010
--Add end

--Add by JGUO 10/14/2010
insert into #TempCabLY
select @year-1 as fiscyear --Add by JGUO 11/10/2009
	, @month as fiscmonth		
       , a.branch 
	,sum(a.Quantity) as CabQty
from SalesDetails a (nolock)
join SalesDetails c (nolock) on a.OrderNumber=c.OrderNumber and (a.line/1000)*1000=c.line and a.line<>c.line
left join metadates  m (NOLOCK) on date=a.invoiceDate
where a.invoiceDate between @LyStaDate and @LyEndDate
	and (a.Item like '%SEW%' or a.Item like '%SEB%' or a.Item like '%-BK%' or a.Item like '%-MI' )
	and a.JDEOrderType in('SP','CO','SO','XX') and C.linetype<>'W'
	and m.BusinessDayOfMonth <= @businessDaysComplete
      --- and a.branch in(select branch from #BranchesTemp) ---Added by ZWANG 12/17/2010--Commented by ZWNAG 02/10/2011
   ---and (@Branch=0 or a.Branch=@Branch)--Add by JGUO 12/07/2010
group by a.branch 

select fiscyear
	, fiscmonth
        , branch 
	, sum(CabQty) as CabQty
into #TempCabLY1
from #TempCabLY
group by fiscyear,fiscmonth,branch




----Get Last fiscal year Data(End)
/*--Commented by ZWNAG 02/10/2011
select fiscyear
	, fiscmonth
	,(case when @Branch = 5000 then co5000/ @daysInMonth when @Branch = 5200 then co5200/ @daysInMonth when @Branch = 0 then (co5000+co5200)/ @daysInMonth end)  as goal5000--, co5000/ @daysInMonth  as goal5000
  into #tempGoals
  from budgetgoals (nolock)
 where fiscyear = @Year and fiscmonth = @Month
*/--Commented by ZWNAG 02/10/2011
update #temp1 
set sales5000_LY = s.SalesMTD
from #tempLY s	
where  s.branch=5000

update #temp1 
set CabQty5000_LY = s.CabQty
from #tempCabLY1 s	
where  s.branch=5000
---Added by ZWANG for Cliq 02/10/2011
update #temp1 
set sales5200_LY = s.SalesMTD
from #tempLY s	
where  s.branch=5200

update #temp1 
set CabQty5200_LY = s.CabQty
from #tempCabLY1 s	
where  s.branch=5200
---Added by ZWANG for Cent 02/10/2011
update #temp1 
set sales5300_LY = s.SalesMTD   --Corrected by ZWANG 2012-01-28(It appears that the 2011 (prior year) totals are incorrect.Cliq totals may actually be Centerpiece totals, and Cliq totals may not appear at all.
from #tempLY s	
where  s.branch=5300

update #temp1 
set CabQty5300_LY = s.CabQty
from #tempCabLY1 s	
where  s.branch=5300

select * 
        ,0 as goal5000
        ,0 as goal5200
        ,0 as goal5300
	, @daysInMonth as daysInMonth
	, @currentBusinessDay as CurrentBusinessDay
        
  from #temp1
Order by Date


	
drop table #temp1
drop table #tempSalesDaily
drop table #kj1
drop table #TempCabDaily--Add By JGUO 08/18/2009
drop table #TempCabDaily1--Add by JGUO 10/14/2010


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

grant execute on dbo.RS_SQ_SalesMonth to public
GO