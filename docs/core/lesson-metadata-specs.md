| lesson-metadata |  |
| :---- | :---- |
| subject | text |
| grade | number |
| unit-id | unique alphanumeric id |
| section-number | number |
| lesson-number  | number |
| lesson-title | text |
| lesson-title-Spanish | text; can be blank |
| lesson-label | Options: required, optional; can be blank |
| lesson-type | text Options: |
| standards | unique alphanumeric codes; comma separated list (e.g., MS-ESS2-4, MS-ESS2-5); codes will connect to spreadsheet with standards language for rendering |
| description | text that describes the lesson: “In this lesson, we…” |
| description-past | text that describes the lesson in past tense language; “In the previous lesson, we…”; will be blank for the last lesson of a unit |
| description-future | text that describes the lesson in future tense language; “In the next lesson, we will…”; will be blank for Lesson 1 |
| learning-targets | text  |
| lms-enabled | Yes or No |
| lms-summary | text; blank if not LMS enabled |
| lms-summary-Spanish | text; blank if not LMS enabled or not translated |

| \[table:lesson-prep\] |  |
| :---- | :---- |
| lesson-prep-time | number |
| lesson-prep-directions  | text |

| activity-metadata |  |
| :---- | :---- |
| activity-title | text |
| activity-title-Spanish | text; can be blank |
| activity-time | number |
| activity-description | Text; can be blank |
| activity-label | Options: required, optional; can be blank |
| activity-type | text or unique alphanumeric code; can be blank Options: |
| activity-type-purpose | text; can be blank |
| slide-id | text; can be blank |
| lms-enabled | Yes or No |
| lms-title | text; If blank, use activity-title; blank if not LMS enabled |
| lms-title-Spanish | text; If blank, use activity-title-Spanish; blank if not LMS enabled |
| lms-instructions | text; blank if not LMS enabled |
| lms-instructions-Spanish | text; blank if not LMS enabled or not translated |
| lms-type | text; blank if not LMS enabled Options: assignment, discussion, assessment, reference ?Quiz, graded survey, survey, non-graded survey? |
| submission-required | Yes or No |
| submission-type | text; can be blank Options: text, recording, URL, file upload (If we remove submission-required and this is blank, then submission-required \= No; if this is filled out then submission-required \= Yes) |
| grading-required | Yes or No |
| grading-format | text; can be blank Options: completion, points (If we remove grading-required and this is blank, then grading-required \= No; if this is filled out then  grading-required \= Yes) |
| total-points | Text; can be blank |
| student-grouping | Options: individual, partners, small group, class  |
| activity-materials-student | text, comma separated list; use the \[material\] tag for LCMS-generated materials; can be blank |
| activity-materials-pair | text, comma separated list; use the \[material\] tag for LCMS-generated materials; can be blank |
| activity-materials-group | text, comma separated list; use the \[material\] tag for LCMS-generated materials; can be blank |
| activity-materials-class | text, comma separated list; use the \[material\] tag for LCMS-generated materials; can be blank |
| activity-metadata-teacher | text, comma separated list; use the \[material\] tag for LCMS-generated materials; can be blank |
| vocabulary | text, comma separated list; can be blank |

| \[lms-materials\] |  |
| :---- | :---- |
| material-id | unique alphanumeric code |
| access-type | Options: individual-submission, shared-submission, view-only |
