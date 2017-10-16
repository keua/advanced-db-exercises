-- Schema
-- Employee (SSN, Name{FName,MInit,LName}, BirthDate, Sex, Salary[x], Address{Street,City,Zip,State}[x])


-- 1) An employee works in at most one department at any point in time.
-- In other terms SSN is a sequenced primary key for Affiliation.
GO
create trigger Seq_PK_Affiliation on Affiliation
after insert, update as
if exists ( 
    select * from Inserted A1
    where 1 < (
        select count(*) from Affiliation A2
        where A1.SSN = A2.SSN
        and A1.FromDate < A2.ToDate and A2.FromDate < A1.ToDate 
    ) 
)
begin
    raiserror ('An employee works in at most one department at any point in time',1,2)
    rollback transaction
end;

-- 2) At any point in time an employee cannot work more than once in a project.
-- In other terms (SSN,PNumber) is a sequenced primary key for WorksOn
GO
create trigger Seq_PK_WorksOn on WorksOn
after insert, update as
if exists (
    select * from Inserted W1
    where 1 < (
        select count(*) from WorksOn W2
        where W1.SSN = W2.SSN and W1.PNumber = W2.PNumber
        and W1.FromDate < W2.ToDate and W2.FromDate < W1.ToDate 
    ) 
)
begin
    raiserror ('At any point in time an employee cannot work more than once in a project',1,2)
    rollback transaction
end;

-- (3) The lifecycle of affiliation is included in the lifecycle of employee.
-- In the following triggers it is assumed that the table EmployeeLifecycle is coalesced.
-- Therefore, every line in Affiliation must be covered by one line in EmployeeLifecycle.
GO
create trigger Seq_FK_Affiliation_EmployeeLifecycle_1 on Affiliation
after insert, update as
if exists ( 
    select * from Inserted A
    where not exists ( 
        select * from EmployeeLifecycle E
        where A.SSN = E.SSN
        and E.FromDate <= A.FromDate and A.ToDate <= E.ToDate 
    ) 
)
begin
    raiserror ('The lifecycle of affiliation must be included in the lifecycle of employee',1,2)
    rollback transaction
end;

GO
create trigger Seq_FK_Affiliation_EmployeeLifecycle_2 on EmployeeLifecycle
after update, delete as
if exists ( 
    select * from Affiliation A
    where A.SSN IN (select SSN from Deleted)
    and not exists ( 
        select * from EmployeeLifecycle E
        where A.SSN = E.SSN
        and E.FromDate <= A.FromDate and A.ToDate <= E.ToDate 
    ) 
)
begin
    raiserror ('The lifecycle of affiliation must be included in the lifecycle of employee',1,2)
    rollback transaction
end;

-- 6(4) The lifecycle of an employee is equal to the union of his/her affiliations. It is
-- supposed that the previous trigger is activated, therefore it is sufficient to monitor
-- that an employee must be affiliated to a department throughout his/her lifecycle.
GO
create trigger Seq_FK_EmployeeLifecycle_Affiliation_1 on Affiliation
after update, delete as
if exists ( 
    select * from EmployeeLifecycle E
    where E.SSN in ( select SSN from Deleted )
    and not exists ( 
        select * from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate <= E.FromDate and E.FromDate < A.ToDate 
    )
    or not exists ( 
        select * from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate < E.ToDate and E.ToDate <= A.ToDate 
    )
    or exists ( 
        select * from Affiliation A
        where E.SSN = A.SSN
        and E.FromDate < A.ToDate and A.ToDate < E.ToDate
        and not exists (
            select * from Affiliation A2
            where A2.SSN = A.SSN
            and A2.FromDate <= A.ToDate and A.ToDate < A2.ToDate 
        ) 
    ) 
)
begin
    raiserror ('An employee must be affiliated to a department throughout his/her lifecycle',1,2)
    rollback transaction
end;

GO
create trigger Seq_FK_EmployeeLifecycle_Affiliation_2 on EmployeeLifecycle
after insert, update as
if exists (
    select * from Inserted E
    where not exists (
        select * from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate <= E.FromDate and E.FromDate < A.ToDate
    )
    or not exists (
        select * from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate < E.ToDate and E.ToDate <= A.ToDate
    )
    or exists (
        select * from Affiliation A
        where E.SSN = A.SSN
        and E.FromDate < A.ToDate and A.ToDate < E.ToDate
        and not exists (
            select * from Affiliation A2
            where A2.SSN = A.SSN
            and A2.FromDate <= A.ToDate and A.ToDate < A2.ToDate
        )
    ) 
)
begin
    raiserror ('An employee must be affiliated to a department throughout his/her lifecycle',1,2)
    rollback transaction
end;

-- (5) Employees have a contiguous lifecycle.
alter table EmployeeLifecycle
drop constraint PK_EmployeeLifecycle;
alter table EmployeeLifecycle
add constraint PK_EmployeeLifecycle primary key (SSN);

-- (6) The lifecycle of an employee is equal to the union of his/her affiliations, now taking
-- into account that the lifecycle of employees is contiguous.
-- It is necessary to ensure that (1) the affiliations of an employee define a contiguous
-- history, and (2) an employee must be affiliated to a department throughout his/her
-- lifecycle.
-- 7The following trigger ensures that the affiliations of an employee define a contiguous
-- history.
GO
create trigger Contiguous_Hist_Affiliation on Affiliation
after insert, update, delete as
if exists (
    select * from Affiliation A1, Affiliation A2
    where A1.SSN = A2.SSN and A1.ToDate < A2.FromDate
    and not exists (
        select * from Affiliation A3
        where A1.SSN = A3.SSN
        and ( ( A3.FromDate <= A1.ToDate and A1.ToDate < A3.ToDate )
        or ( A3.FromDate < A2.FromDate and A2.FromDate <= A3.ToDate ) ) 
    ) 
)
begin
    raiserror ('The affiliations of an employee define a contiguous history',1,2)
    rollback transaction
end;

-- The following two triggers replaces those of question (4).
GO
alter trigger Seq_FK_EmployeeLifecycle_Affiliation_1 on Affiliation
after update, delete as
if exists (
    select * from EmployeeLifecycle E
    where E.SSN in ( select SSN from Deleted )
    and not exists (
        select * from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate <= E.FromDate and E.FromDate < A.ToDate 
    )
    or not exists (
        select * from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate < E.ToDate and E.ToDate <= A.ToDate 
    ) 
) --)
begin
    raiserror ('An employee must be affiliated to a department throughout his/her lifecycle',1,2)
    rollback transaction
end;

GO
alter trigger Seq_FK_EmployeeLifecycle_Affiliation_2 on EmployeeLifecycle
after insert, update as
if exists (
    select * from Inserted E
    where not exists (
        select * from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate <= E.FromDate and E.FromDate < A.ToDate
    )
    or not exists (
        select * from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate < E.ToDate and E.ToDate <= A.ToDate
    ) 
) --)
begin
    raiserror ('An employee must be affiliated to a department throughout his/her lifecycle',1,2)
    rollback transaction
end;

-- 8 Queries
-- (1) Give the name of the managers living currently in Houston
select E.FName, E.LName
from Employee E, EmployeeAddress A, Department D
where E.SSN = A.SSN and E.SSN = D.MgrSSN
    and A.City = 'Houston'
    and A.FromDate <= getdate() and getdate() < A.ToDate
    and D.FromDate <= getdate() and getdate() < D.ToDate;

-- (2) Give the name of employees working currently in the ‘Research' department and
-- having a salary greater or equal than 45000
select E.FName, E.LName
from Employee E, EmployeeSalary S, Affiliation A, Department D
where E.SSN = S.SSN and E.SSN = A.SSN and A.DNumber = D.DNumber
    and D.DName = 'Research' and S.Salary >= 45000
    and S.FromDate <= getdate() and getdate() < S.ToDate
    and A.FromDate <= getdate() and getdate() < A.ToDate;

-- (3) Give the name of current employees who do not work currently in any department
select distinct E.FName, E.LName
from Employee E, EmployeeLifecycle L
where E.SSN = L.SSN
    and L.FromDate <= getdate() and getdate() < L.ToDate
    and not exists (
        select *
        from Affiliation A
        where E.SSN = A.SSN
        and A.FromDate <= getdate() and getdate() < A.ToDate 
    );

-- (4) Give the name of the employee(s) that had the highest salary on 1/1/2002
select E.FName, E.LName
from Employee E, EmployeeSalary S
where E.SSN = S.SSN
    and salary = (
        select max(salary)
        from EmployeeSalary
        where FromDate <= '2002-01-01' and '2002-01-01' < ToDate 
    )
    and S.FromDate <= '2002-01-01' and '2002-01-01' < S.ToDate;

-- (5) Provide the salary and affiliation history for all employees
GO
create function minDate
(@one smalldatetime, @two smalldatetime)
returns smalldatetime as
begin
    return CASE WHEN @one < @two then @one else @two end
end;
go
create function maxDate
(@one smalldatetime, @two smalldatetime)
returns smalldatetime as
begin
    return CASE WHEN @one > @two then @one else @two end
end;
GO
select E.FName, E.LName, D.DName, S.Salary,
    'Start Date' = dbo.maxDate(S.FromDate,A.FromDate),
    'End Date'= dbo.minDate(S.ToDate,A.ToDate)
from Employee E, EmployeeSalary S, Affiliation A, Department D
where E.SSN = S.SSN and E.SSN = A.SSN and A.DNumber = D.DNumber
    and dbo.maxDate(S.FromDate,A.FromDate) < dbo.minDate(S.ToDate,A.ToDate)
order by E.FName, E.LName;
-- (6) Give the name of employees and the period of time in which they were supervisors
-- but did not work in any project during the same period
--Case 1
select S.SuperSSN, S.FromDate, W1.FromDate as ToDate
from Supervision S, WorksOn W1
where S.SuperSSN = W1.SSN
and S.FromDate < W1.FromDate and W1.FromDate < S.ToDate
and not exists (
        select *
        from WorksOn W2
        where S.SuperSSN = W2.SSN
        and S.FromDate < W2.ToDate and W2.FromDate < W1.FromDate
)
union
--Case 2
select S.SuperSSN, W1.ToDate as FromDate, S.ToDate
from Supervision S, WorksOn W1
where S.SuperSSN = W1.SSN
and S.FromDate < W1.ToDate and W1.ToDate < S.ToDate
and not exists (
    select *
    from WorksOn W2
    where S.SuperSSN = W2.SSN
    and W1.ToDate < W2.ToDate and W2.FromDate < S.ToDate 
)
union
--Case 3
select S.SuperSSN, W1.ToDate as FromDate, W2.FromDate as ToDate
from Supervision S, WorksOn W1, WorksOn W2
where S.SuperSSN = W1.SSN and S.SuperSSN = W2.SSN and W1.ToDate < W2.FromDate
and S.FromDate < W1.ToDate and W2.FromDate < S.ToDate
and not exists (
    select *
    from WorksOn W3
    where S.SuperSSN = W3.SSN
    and W1.ToDate < W3.ToDate and W3.FromDate < W2.FromDate 
)
union
--Case 4
select SuperSSN, FromDate, ToDate
from Supervision S
where not exists (
    select *
    from WorksOn W
    where S.SuperSSN=W.SSN
    and S.FromDate < W.ToDate and W.FromDate < S.ToDate 
);

-- (7) Give the name of supervisors who had work on a project at some time
select distinct E.FName, E.LName
from Employee E, Supervision S, WorksOn W
where E.SSN = S.SuperSSN and E.SSN = W.SSN

-- (8) Give the name of employees and the date they changed their affiliation
select distinct E.FName, E.LName, A1.ToDate
from Employee E, Affiliation A1, Affiliation A2
where E.SSN = A1.SSN and E.SSN = A2.SSN
    and A1.ToDate = A2.FromDate and A1.DNumber <> A2.DNumber

-- (9) Give the name of employees and the periods they worked on any project
select distinct E.SSN, E.FName, E.LName, F.FromDate, L.ToDate
from Employee E, WorksOn F, WorksOn L
where E.SSN = F.SSN and F.SSN = L.SSN and F.FromDate < L.ToDate
and not exists ( 
    select *
    from WorksOn M
    where M.SSN = F.SSN
    and F.FromDate < M.FromDate and M.FromDate <= L.ToDate
    and not exists (
        select *
        from WorksOn T1
        where T1.SSN = F.SSN
        and T1.FromDate < M.FromDate and M.FromDate <= T1.ToDate 
    ) 
)
and not exists (
    select *
    from WorksOn T2
    where T2.SSN = F.SSN
    and ( ( T2.FromDate < F.FromDate and F.FromDate <= T2.ToDate )
    or ( T2.FromDate <= L.ToDate and L.ToDate < T2.ToDate ) ) 
)