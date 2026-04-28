# Unit Metadata Specification

This document defines the `unit-metadata` table expected in Google Docs sources.

## Table Name

`unit-metadata`

## Fields

| Field | Type | Notes |
| :---- | :---- | :---- |
| `subject` | text | Required |
| `grade` | number | Required |
| `course` | text | Optional, can be blank |
| `unit-id` | unique alphanumeric id | Required |
| `unit-title` | text | Required |
| `unit-title-Spanish` | text | Optional, can be blank |
| `unit-topic` | text | Required |
| `unit-topic-Spanish` | text | Optional, can be blank |
| `description` | text | Required |
| `copyright` | text | Optional, can be blank |
| `license` | text | Optional, can be blank |
| `acknowledgements` | text | Optional, can be blank |
| `unit-materials` | comma separated list | Materials aligned to the unit level, using material ids |

## Validation Expectations

`subject`
: required text value

`grade`
: required numeric value

`course`
: optional text value

`unit-id`
: required unique alphanumeric value

`unit-title`
: required text value

`unit-title-Spanish`
: optional text value

`unit-topic`
: required text value

`unit-topic-Spanish`
: optional text value

`description`
: required text value

`copyright`
: optional text value

`license`
: optional text value

`acknowledgements`
: optional text value

`unit-materials`
: optional comma-separated list of material identifiers
