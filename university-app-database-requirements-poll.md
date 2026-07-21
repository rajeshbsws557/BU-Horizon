# University App Database Requirements Poll

Use this questionnaire to define the academic structure, roles, permissions, workflows, and operational requirements for the university application.


## Academic Structure

1. **What does one department offer?**
   -  One BSc program


2. **Which academic systems are used?**
   -  semister or yearly, depending on the program

3. **Can a program change between semester and year systems?**
   -  No

4. **How is a batch identified?**
   -  Admission year As well as Academic session, such as 2025-26

5. **Can one batch have sections or groups?**
   -  No

6. **Can students change batches or departments?**
   - No

7. **Must graduated, delayed, suspended, and archived batches remain accessible?**
   - Must be done in 2 segments , 1st one is when a student gets dropped out or becomes not promoted in a semester or year final exam ;
       He can make a request in the app (a request section is needed in the app) to His current batch class representative (CR) then the CR of
       the batch (that the dropped out student will be dropped out to) will receive that request and if he accepts then the current batch of the 
       dropped out student will be changed.

8. **Can different batches be in the same semester or year because of session delays?**
   -  No

9. **Who controls academic dates?**
   - No acedamic calender needed . The batch CR will decide on the extention / end of a semester.

10. **Who advances a batch to its next semester or year?**
    - The batch CR will decide on the extention / end of a semester.

## Courses and Teachers

11. **Should courses and course codes be stored?**
    -  Yes

12. **Can the same course appear in multiple departments or programs?**
    -  No

13. **Can courses be elective, repeated, improvement, or retake courses?**
    -  No

14. **Will teachers have accounts?**
    -  No

15. **Can teachers belong to multiple departments?**
    -  No

16. **Can multiple teachers teach one course offering?**
    -  No

## Accounts and Registration

18. **Who can register an account?**
    -  Students
    - For CR accounts -> Nobody; administrators create all CR accounts.

19. **Who approves registrations?**
    - Registration is approved automatically
 
20. **Which identity information is required?** **(Multi-select)**
    -  Name
    -  Roll
    -  Student ID Number (Obtained From Student ID card)
    -  University email (name@bu.ac.bd) ONLY / Student ID ONLY.
    -  Phone number
    -  session (Only takes formats like - 2025-26 , 2024-25 , etc....)
    -  Faculty
    -  Department

21. **Can one person have multiple roles simultaneously?**
    -  No

22. **Which login methods should be supported?** **(Multi-select)**
    -  Email / Student ID and password

23. **How should account recovery work?**
    -  Phone Number (Otp send to Number) / Email (Otp send to mail)


## Roles and Isolation

25. **Which roles are required?** **(Multi-select)**
    -  Student (and CR BUt CR is basically student with some CRUD Priviliges)


28. **Can users view content from other departments?**
    -  Never
    -  Public notices only

29. **Can users view content belonging to other batches in their department?**
    -  Never
 

30. **Should permissions be individually configurable beyond fixed roles?**
    -  No

## Class Representative Management

31. **How many class representatives can a batch have?**
    -   One (Maximum 2).


32. **Who appoints and removes class representatives?**
    -  Super administrator only

33. **Should class representative appointments have start dates, end dates, and assignment history?**
    -  No

34. **Which operations can class representatives perform?** **(Multi-select)**
    -  Manage each individual class schedules (Full CRUD Operation)
    -  Manage each individual class attendance (Full CRUD Operation)
    -  Manage each individual class notices (Full CRUD Operation)
    -  Manage each individual class resources (Full CRUD Operation)
    -  Manage each individual class exam notices And Final exam notices. (Full CRUD Operation)
    -  Manage batch members (For the dropped ou students requests accepting Only)

35. **Can class representatives permanently delete data?**
    - No; soft-delete only

36. **Does content created by a class representative require approval?**
    -  Never


## Attendance

37. **How should attendance be recorded?**
    - Each individual course and individual class 
  

38. **Which attendance statuses are required?** **(Multi-select)**
    -  Present
    -  Absent


39. **Who records attendance?**
    -  Class representative
 

41. **Can attendance be edited after submission?**
    -  At any time, with an audit history

42. **Should students be able to submit attendance correction requests?**
    -  Yes

43. **Which attendance reports are required?** **(Multi-select)**
    -  Attendance percentage
    -  Course-wise report
    -  Attendance-shortage list
    -  PDF or Excel export

## Schedules and Exams

44. **Which schedule types are required?** **(Multi-select)**
    -  One-time class
    -  Rescheduled class
    -  Cancelled class
    -  Online class

45. **Should schedules store rooms, floor of the building, teachers, courses (Optional), and meeting links (If class is in online)?**
    -  Selected fields only

46. **Should the system automatically detect room, teacher, and batch time conflicts?**
    -  Yes (CR will solve the conflict between the conflicted batch CR and him).

47. **Which exam-related data should be managed?** **(Multi-select)**
    -  Exam notices
    -  Exam routines

48. **Should exam information be associated with courses?**
    -  Yes


## Notices and Resources

49. **Which audiences can content target?** **(Multi-select)**
    -  Entire university (Public notices only - By super administrator)
    -  Batch

50. **Which notice states are required?**
    -  Draft, scheduled, published, and archived

51. **Which notice features are required?** **(Multi-select)**
    -  Attachments
    -  Expiration
    -  Priority
    -  Pinning
    -  Read confirmation

52. **Which resource types should be supported?** **(Multi-select)**
    -  PDF and document files
    -  Images
    -  External links

53. **Where should uploaded files be stored?**
    -  Cloud or object storage (e.g. Cludflared R2, etc... "I will decide later").

54. **Should resources support versions and upload history?**
    -  No (Date-Time only for upload history)

## Notifications

55. **Which notification channels should be supported?** **(Multi-select)**
    -  In-app
    -  Push notifications

56. **Which changes should trigger notifications?**
    - Important changes only (Every change made by CR) AND public notices.

57. **Should users be able to mark notices as read or acknowledged?**
    - Yes

## Administration and Security

58. **Should privileged changes have immutable audit logs?**
    -  Yes

59. **What should the deletion policy be?**
    - Soft-delete with restoration (Only for CR CRUD Operations).

60. **Can the super administrator impersonate users for support purposes?**
    - No

61. **Who should be required to use two-factor authentication?**
    - All users


63. **Which export formats or operations should administrators have?** **(Multi-select)**
    -  CSV
    -  Excel
    -  PDF
    -  Database backup

64. **Should a deleted user's academic records remain preserved?**
    - Yes

65. **How frequently should backups be created?**
    - Manually

## Operational Decisions

66. **How many total users are expected?**
    -  Fewer than 5,000 (At most 10000 in future)

67. **Which languages should the application support?**
    - Both English and Bangla

68. **Which platforms should be supported?**
    -  Web, Android, and iOS

69. **Is integration with an existing university system required?**
    -  No

70. **Is the system intended for one university only?**
    -  Yes
