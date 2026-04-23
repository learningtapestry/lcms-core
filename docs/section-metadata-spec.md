# Section Metadata Specification

This document defines the standalone `section-metadata` table expected in Google Docs sources.

## Table Name

`section-metadata`

## Fields

| Field | Type | Notes |
| :---- | :---- | :---- |
| `subject` | text | Required |
| `grade` | number | Required |
| `unit-id` | unique alphanumeric id | Required |
| `section-number` | number | Required |
| `section-title` | text | Required |
| `section-title-Spanish` | text | Optional, can be blank |
| `description` | text | Required |
| `section-materials` | comma separated list | Optional; use material ids |
