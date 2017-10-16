-- Schema
-- Professor (ProfNo,Name,Laboratory)
-- Professor ->> PhDStudent(StudentNo,NameLaboratory,Supervisor)
-- Professor ->> Course (CourseNo,Title,ProfNo)
-- Cours ->> CourseTaken (StudentNo,CourseNo) <<- PhDStudent

-- Define in SQL Server a set of triggers that ensure the following constraints:

-- Exercise 1. A PhD student must work in the same laboratory as his/her supervisor.

-- Events that may violate the constraint
-- a) Insert into PhDStudent
-- b) Update of Laboratory or Supervisor in PhDStudent
-- c) Update of Laboratory in Professor
-- d) Delete from Professor

-- Events a) and b)
-- 1. Aborting the transaction
create trigger StudSameLabAsSuperv_PhDStud_InsUpd_Abort
on PhDStudent
after insert, update
as
if exists (
    select *
    from Inserted I, Professor P -- We take from the Insterd table if some PhD student was updated or inserted
    where P.ProfNo = I.Supervisor -- we take the supervisor assigned to the student
    and P.Laboratory <> I.Laboratory -- if there is a different laboratory assigned Raise an error 
)
begin
    raiserror ('Constraint Violation:A PhD student must work in the same laboratory as his/her supervisor',1,2)
    rollback
end;
-- 2. Repairing the transaction
GO
create trigger StudSameLabAsSuperv_PhDStud_InsUpd_Repair
on PhDStudent
after insert, update
as
begin
update PhDStudent
set Laboratory = ( -- Assign the Supervisor laboratory
    select P.Laboratory
    from Professor P
    where P.ProfNo = Supervisor 
    )
where StudentNo in ( -- To the Students who are being inserted
    select I.StudentNo
    from Inserted I 
    )
end;
-- In this case, repairing by making the necessary updates in PhDStudent will probably be the better choice, as the value
-- that Laboratory should take is univocally determined by the consistency rule.

-- Event c)
-- 1. Aborting the transaction
GO
create trigger StudSameLabAsSuperv_Prof_Upd_Abort
on Professor
after update
as
if exists ( -- if exists raise an error that will rollback the transaction
    select * from Inserted I, PhDStudent S -- Select the updated professors
    where I.ProfNo = S.Supervisor -- who are supervisors
    and I.Laboratory <> S.Laboratory -- and their laboratories changed
)
begin
    raiserror ('Constraint Violation:A PhD student must work in the same laboratory as his/her supervisor',1,2) -- error
    rollback
end;
-- 2. Repairing the violated constraints
GO
create trigger StudSameLabAsSuperv_Prof_Upd_Repair
on Professor
after update
as
begin
    update PhDStudent
    set Laboratory = ( -- update the phdstudents laboratory thah chang from their supervisor
        select I.Laboratory -- selecting the updated laboratory 
        from Inserted I -- from inserted table
        where Supervisor = I.ProfNo -- that belong to the supervisors
    )
    where Supervisor in ( -- where the supervisor is in the insertedc table
        select I2.ProfNo
        from Inserted I2 
    )
end;
-- Again, repairing the violated constraints should be preferred in this case too. The assumption is that, when a professor
-- leaves her lab for another one, her PhD students are following.

-- Event d)
-- In this case, there are several possibilities.
-- • The professor is deleted and the attributes Laboratory and Supervisor of the PhD students who worked for the
-- deleted professor are set to null.
-- • The transaction is rolled back, preventing a professor to be deleted when there are PhD students associated to her.
-- This is taken care of by the referential integrity.
-- • The professor is deleted and all PhD students associated with him are also deleted. This is taken care of by the referential integrity with the option on update cascade.
-- We here provide the trigger corresponding to the first of these cases.
GO
alter table PhDStudent
drop constraint FK_PhDStudent_Professor; -- We are dropping the constraint to be able to set null the professor in the phstudent table
GO
create trigger StudSameLabAsSuperv_Prof_Del_Repair
on Professor
after delete
as
begin
    update PhDStudent -- we are updating the phdstudent
    set Laboratory = null, -- we are setting null the laboratory
    Supervisor = null -- we are setting null the supervisor
    where Supervisor in ( -- from the deleted supervisors
        select ProfNo
        from Deleted 
    )
end;
-- B CAUTION As SQL Server does not implement the option on delete set null for the referential integrity,
-- it is necessary to drop the foreign key constraint in the table PhDStudent.

-- Exercise 2. A PhD student must take at least one course.
-- Events that may violate the constraint
-- a) Insert into PhDStudent
-- b) Update of StudentNo in CourseTaken
-- c) Delete from CourseTaken
-- d) Delete from Course
-- Event a)
GO
create trigger PhDStudMinOneCourse_PhDStud_Ins_Abort
on PhDStudent
after insert
as
if exists ( -- raise an error if exists any result
    select * from Inserted I -- we are selecting the data in the inserted table
    where not exists (-- execute if does not exist any result
        select * -- selecting all
        from CourseTaken -- from the coruse taken table
        where StudentNo = I.StudentNo -- where student is in the inserted table
    ) 
)
begin
    raiserror ('Constraint Violation: A PhD student must take at least one course',1,2)
    rollback
end;

-- Events b) and c)
GO
create trigger PhDStudMinOneCourse_PhDStud_Ins_Abort
on CourseTaken
after update, delete
as
if exists ( -- if any result exist raise an error
    select * from Deleted D -- selecting data from the deleted table
    where D.StudentNo not in ( -- for the students who are not in the
        select StudentNo -- selecting students from the
        from CourseTaken -- course taken table
    ) 
)
begin
    raiserror ('Constraint Violation: A PhD student must take at least one course',1,2)
    rollback
end;

-- Event d)
-- Removing an entry from Course could indirectly affect the number of courses taken by one or several PhD students. This
-- case, however, should be handled with the on update cascade option of the referential integrity constraint on the
-- CourseNo field of CourseTaken.

-- Exercise 3. A PhD student must take all courses taught by his/her supervisor

-- Events that may violate the constraint
-- a) Insert into PhDStudent
-- b) Update of Supervisor in PhDStudent
-- c) Insert into Course
-- d) Update of ProfNo in Course
-- e) Update of StudentNo or CourseNo in CourseTaken
-- f) Delete from CourseTaken
-- Events a) and b)
-- 1. Aborting the transaction
GO
create trigger StudAllCoursesOfSuperv_Stud_InsUpd_Abort
on PhDStudent
after insert, update
as
if exists ( -- if any result is returned
    select * from Inserted I -- select data from the inserted table
    where exists ( -- if any result is returned
        select * -- select data
        from Course C -- from the course table
        where C.ProfNo = I.Supervisor -- where the professor is a supervisor from the inserted student
        and C.CourseNo not in ( -- and the course is not in 
            select T.CourseNo -- selecting the courses
            from CourseTaken T -- from the corusetaken table
            where T.StudentNo = I.StudentNo -- where student is being inserted
        ) 
    ) 
)
begin
    raiserror ('Constraint Violation: A PhD student must take all the courses given by his supervisor',1,2)
    rollback
end;

-- 2. Repairing the transaction
GO
create trigger StudAllCoursesOfSuperv_Stud_InsUpd_Repair
on PhDStudent
after insert, update
as
begin
    insert into CourseTaken (StudentNo, CourseNo) -- we are inserting a student and course in the course taken table
        select I.StudentNo, C.CourseNo -- select student number and course number
        from Inserted I, -- from the inserted table
        Professor P, -- professor table
        Course C -- and cours table
        where I.Supervisor = P.ProfNo -- where the professor from the inserted table is a supervisor
        and C.ProfNo = P.ProfNo -- and the course professor match with the professor table
        and C.CourseNo not in ( -- and the course number is not in
            select T.CourseNo -- select course number
            from CoursTaken T -- from course taken table
            where T.StudentNo = I.StudentNo  -- where the student match with the inserted student
        )
end;
-- The rules implemented by this trigger can be challenged, for instance, with the following change of supervisor for the
-- student named Joyce. The lab she belongs to will automatically be changed to “Web Technologies” by the trigger.
begin transaction
update PhDStudent
set Supervisor = 66688
where StudentNo = 453453453
commit transaction;

-- Events c) and d)
GO
create trigger StudAllCoursesOfSuperv_Course_InsUpd_Repair
on Course
after insert, update
as
begin
    insert into CourseTaken (StudentNo, CourseNo)
        select S.StudentNo, I.CourseNo
        from Inserted I,
        Professor P,
        PhDStudent S
        where C.ProfNo = P.ProfNo
        and S.Supervisor = P.ProfNo
        and I.CourseNo not in (
            select T.CourseNo
            from CourseTaken T
            where T.StudentNo = C.StudentNo 
        )
end;
-- Events e) and f)
GO
create trigger StudAllCoursesOfSuperv_CourseTaken_UpdDel_Abort
on CourseTaken
after update, delete
as
if exists (
    select *
    from Deleted D,
    Course C,
    PhDStudent S
    where D.CourseNo = C.CourseNo
    and C.ProfNo = S.Supervisor
    and D.StudentNo = S.StudentNo 
)
begin
    raiserror ('Constraint Violation: A PhD student must take all the courses given by his supervisor',1,2)
end