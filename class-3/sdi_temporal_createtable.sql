create database ...
go
use ...
create table Employee (
  SSN char(9) not null,
  FName varchar(15) not null,
  MInit char(1),
  LName varchar(15) not null,
  BirthDate smalldatetime null,
  Sex char(1),
  constraint PK_Employee primary key (SSN),
) 
create table EmployeeLifecycle (
  SSN char(9) not null,
  FromDate smalldatetime not null default getdate(),
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_EmployeeLifecycle primary key (SSN,FromDate),
  constraint FK_EmployeeLifecycle_Employee foreign key (SSN) references Employee (SSN),
  constraint Period_EmployeeLifecycle check (FromDate < ToDate) 
) 
create table EmployeeSalary (
  SSN char(9) not null,
  Salary decimal(18,2),
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_EmployeeSalary primary key (SSN,FromDate),
  constraint FK_EmployeeSalary_Employee foreign key (SSN) references Employee (SSN),
  constraint Period_EmployeeSalary check (FromDate < ToDate) 
) 
create table EmployeeAddress (
  SSN char(9) not null,
  Street varchar(20),
  City varchar(20),
  Zip varchar(10),
  State varchar(10),
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_EmployeeAddress primary key (SSN,FromDate),
  constraint FK_EmployeeAddress_Employee foreign key (SSN) references Employee (SSN),
  constraint Period_EmployeeAddress check (FromDate < ToDate) 
) 
create table Supervision (
  SSN char(9) not null,
  SuperSSN char(9) not null,
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_Supervision primary key (SSN,SuperSSN,FromDate),
  constraint FK_Supervision_Employee_Emp foreign key (SSN) references Employee (SSN),
  constraint FK_Supervision_Employee_Super foreign key (SuperSSN) references Employee (SSN),
  constraint Period_Supervision check (FromDate < ToDate) 
) 
create table Department (
  DNumber int not null,
  DName varchar(15) not null,
  MgrSSN char(9) not null,
  MgrStartDate smalldatetime,
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_Department primary key (DNumber),
  constraint FK_Department_Employee foreign key (MgrSSN) references Employee (SSN) 
    on delete cascade on update cascade,
  constraint Period_Department check (FromDate < ToDate) 
) 
create table Affiliation (
  SSN char(9) not null,
  DNumber int not null,
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_Affiliation primary key (SSN,FromDate),
  constraint FK_Affiliation_Employee foreign key (SSN) references Employee (SSN),
  constraint FK_Affiliation_Department foreign key (DNumber) references Department (DNumber),
  constraint Period_Affiliation check (FromDate < ToDate) 
) 
create table DeptNbEmp (
  DNumber int not null,
  NbEmp  int,
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_DepartmentNbEmp primary key (DNumber,FromDate),
  constraint FK_DepartmentNbEmp_Department foreign key (DNumber) references Department (DNumber) 
    on delete cascade on update cascade,
  constraint Period_DeptNbEmp check (FromDate < ToDate) 
) 
create table DeptLocations (
  DNumber int not null,
  DLocation varchar(15) not null,
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_DeptLocations primary key (DNumber,DLocation,FromDate),
  constraint FK_DeptLocations_Department foreign key (DNumber) references Department (DNumber),
  constraint Period_DeptLocations check (FromDate < ToDate) 
) 
create table Project (
  PNumber int not null,
  PName varchar(15) not null,
  PLocation varchar(15),
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_Project primary key (PNumber),
  constraint Period_Project check (FromDate < ToDate) 
) 
create table Controls (
  PNumber int not null,
  DNumber int not null,
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_Controls primary key (PNumber,FromDate),
  constraint FK_Controls_Department foreign key (DNumber) references Department (DNumber),
  constraint Period_Controls check (FromDate < ToDate) 
) 
create table WorksOn (
  SSN char(9) not null,
  PNumber int not null,
  Hours decimal(18,1) not null,
  FromDate smalldatetime not null,
  ToDate smalldatetime not null default '2079-01-01',
  constraint PK_WorksOn primary key (SSN,PNumber,FromDate),
  constraint FK_WorksOn_Employee foreign key (SSN) references Employee (SSN),
  constraint FK_WorksOn_Project foreign key (PNumber) references Project (PNumber),
  constraint Period_WorksOn check (FromDate < ToDate) 
) 


