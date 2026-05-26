---
name: semantic-view-from-yaml
description: "Create Snowflake Semantic Views from YAML files using SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML. Use when: creating semantic views from YAML, converting YAML semantic models to semantic views, debugging YAML-to-semantic-view errors. Triggers: semantic view from yaml, yaml to semantic view, SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML, create semantic view from yaml, convert yaml to semantic view."
---

# Create Semantic View from YAML

Create Snowflake Semantic Views from YAML semantic model files using `SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML`.

## When to Use

- User has a YAML semantic model file and wants to create a Semantic View
- User wants to convert an existing Cortex Analyst YAML model to a Semantic View
- User encounters errors creating Semantic Views from YAML

## Workflow

### Step 1: Read and Validate the YAML File

1. **Read** the user's YAML file
2. **Validate** with `cortex reflect`:
   ```bash
   cortex reflect <path_to_yaml>
   ```
3. If validation fails, fix the YAML before proceeding

### Step 2: Create the Semantic View

Use `SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML` (not `CREATE SEMANTIC VIEW ... FROM` which does not exist):

```sql
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  '<DATABASE>.<SCHEMA>',
  $$
<YAML content here>
$$
);
```

**Parameters:**
- Arg 1: Fully qualified schema name (must include database, e.g. `MY_DB.MY_SCHEMA`)
- Arg 2: YAML specification as a string (use `$$` dollar-quoting)
- Arg 3 (optional): `TRUE` to verify only without creating

**The Semantic View name comes from the `name:` field in the YAML, not from the SQL.**

### Step 3: Verify Creation

```sql
SHOW SEMANTIC VIEWS IN SCHEMA <DATABASE>.<SCHEMA>;
```

## Known Pitfalls and Solutions

### 1. Relationship `many_to_one` Key Constraint Error

**Error:**
```
The referenced key in the relationship 'TABLE_A REFERENCES TABLE_B'
must be the primary or unique key of the referenced entity.
```

**Cause:** `relationship_type: many_to_one` requires the right table's join column to be its primary key or unique key. If the join column is not PK/UK, this error occurs.

**Solutions (in order of preference):**
1. Change `relationship_type` to `many_to_many` -- but note this may not be supported in YAML-to-SV conversion
2. Add a `UNIQUE` constraint on the right table's join column if appropriate
3. Remove the relationship entirely and keep tables independent

### 2. `many_to_many` Not Supported in YAML Conversion

**Error:** `Invalid semantic model YAML` when using `relationship_type: many_to_many`.

**Solution:** Remove the relationship from the YAML. The tables will be independent within the Semantic View. Cortex Analyst can still answer questions about each table separately.

### 3. `cortex reflect` Passes but `SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML` Fails

`cortex reflect` validates YAML structure for Cortex Analyst (semantic model file usage). Semantic Views have stricter constraints (e.g., relationship key requirements). A YAML that passes reflect may still fail SV creation.

**Solution:** After `cortex reflect`, also run with `verify_only = TRUE`:
```sql
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  '<DATABASE>.<SCHEMA>',
  $$ <YAML> $$,
  TRUE
);
```

### 4. Wrong Function Name

These do NOT exist:
- `SNOWFLAKE.CORTEX.CREATE_SEMANTIC_VIEW_FROM_YAML`
- `CREATE SEMANTIC VIEW ... FROM SEMANTIC MODEL @stage/file.yaml`
- `CREATE SEMANTIC VIEW ... AS SEMANTIC MODEL FROM ...`

The correct syntax is always:
```sql
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(...)
```

## Using Semantic View in Cortex Agent

After creating the Semantic View, reference it in Cortex Agent with `semantic_view` (not `semantic_model_file`):

```json
{
  "tool_resources": {
    "tool_name": {
      "semantic_view": "<DATABASE>.<SCHEMA>.<SEMANTIC_VIEW_NAME>"
    }
  }
}
```

For YAML on a stage (without Semantic View), use `semantic_model_file`:

```json
{
  "tool_resources": {
    "tool_name": {
      "semantic_model_file": "@<DATABASE>.<SCHEMA>.<STAGE>/<file>.yaml"
    }
  }
}
```

## Stopping Points

- After Step 1: If YAML validation fails, stop and fix
- After Step 2: If relationship errors occur, ask user how to handle

## Output

A Semantic View created in the specified schema, ready for use with Cortex Analyst or Cortex Agent.
