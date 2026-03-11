# Salesforce AI-Assisted Development Guide for Copilot

**Last Updated**: February 2026  
**Purpose**: Complete reference for AI-assisted Salesforce development using GitHub Copilot, Claude, or similar assistants.

## Quick Start

### Prompt Recipe (Plan → Diff → Implement → Tests → Deploy)

```text
You are implementing Salesforce changes in an SFDX repo.
Follow docs/ai/* standards.

Process:
1) Plan: list impacted metadata and risks.
2) Diff: summarize exact files to change and why.
3) Implement: produce minimal, standards-compliant edits.
4) Tests: add/update Apex/LWC/Flow test strategy and run checks.
5) Deploy: provide validation + deployment commands and rollback notes.

Constraints:
- Enforce CRUD/FLS and user-mode/system-mode guidance.
- No hardcoded endpoints, secrets, IDs, or tokens.
- Use Named Credentials / External Credentials for callouts.
- Include recursion/idempotency protections for Trigger + Flow interplay.
```

### How to Use These Docs as Context

1. **Provide scope**: Include object(s), flow(s), Apex class(es), and metadata in scope.
2. **Attach these docs**: Include this file or key sections as working context.
3. **Require plan-first execution**: Ask the agent to present a plan before implementation.
4. **Require standards references**: Require file-level references to these rules in outputs.
5. **Gate on Definition of Done**: Do not merge unless **Definition of Done** is satisfied.

---

## Part 1: Core Standards

### Agent Rules

**Purpose**: Govern AI agents modifying this Salesforce SFDX repository.

#### Core Rules

- Agents **MUST** produce a short implementation plan before editing files.
- Agents **MUST** list exact files to be changed before writing code.
- Agents **MUST** prefer small, focused diffs over broad refactors.
- Agents **MUST NOT** modify unrelated metadata.
- Agents **MUST** follow all standards in this folder and cite them in summary.
- Agents **MUST** preserve existing package/module boundaries.
- Agents **MUST NOT** add secrets, access tokens, org credentials, or hardcoded IDs.

#### Salesforce-Specific Rules

- Agents **MUST** enforce CRUD/FLS in Apex entry points and data access paths.
- Agents **MUST** account for **User Mode vs System Mode** behavior in Apex, Flow, and integrations.
- Agents **MUST** design for bulk operations (up to 200 records per transaction).
- Agents **MUST** include trigger/flow recursion and idempotency protections.
- Agents **MUST** use Named Credentials / External Credentials for HTTP callouts.
- Agents **MUST NOT** hardcode endpoints or tokens.

#### Output Contract for Agents

Every implementation response **MUST** include:
1. Plan
2. File diff summary
3. Security notes
4. Test updates + commands
5. Deployment validation commands

---

### Definition of Done (DoD)

A change is done only when **all** applicable checks below pass.

#### Functional Completion

- ✅ Requirement acceptance criteria are met.
- ✅ Metadata compiles and validates in target org(s).
- ✅ Backward compatibility impact is documented.

#### Security & Compliance

- ✅ CRUD/FLS enforcement is present and tested.
- ✅ User Mode vs System Mode decision is explicit.
- ✅ No hardcoded endpoints, tokens, or credentials.
- ✅ Integrations use Named Credentials / External Credentials.

#### Engineering Quality

- ✅ Bulk-safe logic for 200-record transactions.
- ✅ Recursion/idempotency controls for trigger+flow interactions.
- ✅ Fault handling for Flows and callouts is implemented.
- ✅ Logging/observability events are added for critical operations.

#### Testing

- ✅ Apex tests follow AAA and cover success + negative + bulk + async scenarios.
- ✅ Callouts are mocked.
- ✅ `SeeAllData=true` is not used unless justified and approved.
- ✅ Minimum org deployment threshold is respected (**Salesforce platform minimum is 75%** overall Apex coverage).

#### Release Readiness

- ✅ Dependency order reviewed (objects → fields → record types → layouts → flows → code → permsets).
- ✅ Validation deployment executed before production deployment.
- ✅ Rollback plan included.
- ✅ Destructive changes are isolated and explicitly approved.

**Do / Don't**:
- **Do** block merge until all DoD items are complete.
- **Do** provide a concise risk register per deployment.
- **Don't** mark done based only on local compile.
- **Don't** skip security/test evidence in PR descriptions.

---

### Architecture Standards

#### Architectural Principles

- Design **MUST** separate domain logic from transport concerns (UI/API/Flow triggers).
- Business rules **SHOULD** be centralized in Apex service/domain layers.
- Integrations **MUST** isolate provider-specific logic behind interfaces.
- Metadata design **MUST** prefer declarative where maintainable and observable.

#### Recommended Layering

1. **Entry Layer**: Trigger handlers, invocable actions, REST controllers, LWCs.
2. **Application Layer**: Orchestration services and transaction boundaries.
3. **Domain Layer**: Core business rules, validation, idempotency.
4. **Infrastructure Layer**: DML wrappers, selectors, HTTP clients, platform events.

#### Trigger + Flow Interaction Model

- Use one trigger per object with handler delegation.
- Triggers and record-triggered flows **MUST** be idempotent.
- Recursion guards **MUST** prevent repeated updates in same transaction.
- When Flow updates can retrigger automation, guard with change-detection checks.

#### User Mode vs System Mode

- Entry points handling end-user initiated actions **SHOULD** prefer user-context operations when feasible.
- Privileged operations in system mode **MUST** be narrow, documented, and audited.
- Any escalation path **MUST** enforce least privilege and explicit authorization checks.

#### Data Design Considerations

- Use external IDs for matching/upsert and integration idempotency keys.
- Use selective filters and indexes for large-data-volume queries.
- Keep object ownership and sharing model aligned to access needs.

---

### Naming Conventions

#### Global Standards

- Names **MUST** be descriptive, stable, and domain-oriented.
- Names **MUST** use a project prefix for custom artifacts (e.g., `FT_` for Apex class names).
- Abbreviations **SHOULD** be minimized unless industry-standard.

#### Apex

- Classes: `FT_<Domain><Role>` (e.g., `FT_AssignmentService`).
- Interfaces: `IFT_<Capability>`.
- Tests: `<ClassName>Test`.
- Methods: verbs for actions, nouns for getters/selectors.

#### LWC

- Folder names: lower camel case (e.g., `ftClientDashboard`).
- JS classes: PascalCase.
- Public API properties: meaningful `@api` names.

#### Metadata

- Custom Objects/Fields: use clear labels and stable API names.
- Flows: `<Domain>_<Event>_<Type>` (e.g., `TrainingSession_AfterSave_RecordTriggered`).
- Validation Rules: `VR_<Object>_<RuleIntent>`.
- Permission Sets: `PS_<DomainOrRole>`.
- Permission Set Groups: `PSG_<DomainOrRole>`.
- Custom Metadata Types/Records: `CMDT_<Domain>` and semantic developer names.

---

### Security Model Standards

#### Core Security Requirements

- All data access logic **MUST** consider CRUD, FLS, sharing, and execution mode.
- Security checks **MUST** be explicit at service boundaries.
- Privileged operations **MUST** be narrowly scoped and auditable.

#### User Mode vs System Mode Guidance

- User mode execution **SHOULD** be used for user-driven operations where feasible.
- System mode execution **MAY** be used for controlled platform automation needs.
- When using system mode, code **MUST** apply compensating controls:
  - Object/field accessibility checks.
  - Record-level access checks when required by policy.
  - Business authorization checks (e.g., role/custom permission).

#### CRUD/FLS Enforcement Patterns

- Entry-layer Apex (controllers, invocables, REST) **MUST** enforce object and field access.
- Queries **SHOULD** use patterns that prevent returning unauthorized fields.
- DML payloads **MUST** remove inaccessible fields before save when needed.

#### Flow Security

- Flow designers **MUST** document context and access expectations.
- Screen flows **SHOULD** avoid exposing fields users cannot edit by policy.
- Invocable Apex called by Flow **MUST** enforce its own security assumptions.

#### Secret and Credential Handling

- Secrets **MUST** never be stored in code, custom settings, or custom metadata plain text.
- Callout auth **MUST** use Named Credentials + External Credentials.
- Tokens/endpoints **MUST NOT** be hardcoded.

---

### Apex Standards

#### Core Design Rules

- Apex **MUST** be bulkified and transaction-safe.
- Business logic **MUST** live in services/domain classes, not triggers/controllers.
- Classes **SHOULD** have single, clear responsibilities.

#### Trigger Standards

- One trigger per object.
- Trigger logic **MUST** delegate to a handler/service class.
- Trigger handlers **MUST** implement recursion guards and idempotency checks.
- Trigger code **MUST** handle insert/update/delete/undelete contexts explicitly.

#### DML and Query Standards

- Never perform SOQL/DML inside unbounded loops.
- Query only needed fields.
- Use selectors/repositories for repeatable query patterns where helpful.

#### Integration in Apex

- Callout code **MUST** use Named Credentials / External Credentials.
- Endpoints and auth tokens **MUST NOT** be hardcoded.
- Retry/backoff and error mapping **SHOULD** be centralized.

---

### Flow Standards

#### Flow Design Rubric

##### Before-Save vs After-Save

- **Before-save record-triggered flow** **MUST** be used for in-record field updates when no related records/callouts are required.
- **After-save record-triggered flow** **MUST** be used for related records, async actions, platform events, or callouts via invocable Apex.
- Avoid using after-save for simple same-record updates due to performance overhead.

##### Subflows

- Shared business logic **SHOULD** be moved into autolaunched subflows.
- Subflows **MUST** have clear input/output contracts and descriptions.

##### Fault Paths (Required)

- Every DML/action element **MUST** have a fault path.
- Fault paths **MUST** log enough context for support triage.
- User-facing flows **SHOULD** show actionable error messaging.

#### Trigger + Flow Coexistence

- Trigger and Flow logic on same object **MUST** include idempotency checks.
- Changes emitted by one automation **MUST NOT** endlessly retrigger the other.
- Use decision nodes and "changed fields" filters to prevent no-op reprocessing.

#### Limits and Performance

- Flows **MUST** be designed for bulk operations (up to 200 records).
- Avoid per-record SOQL/DML patterns in loops.
- Use collection operations and scheduled/asynchronous patterns where needed.

#### Invocable Apex Guidance

- Invocable Apex **MUST** be bulkified and fault-tolerant.
- Invocables **MUST** enforce CRUD/FLS and mode assumptions.
- Invocables for callouts **MUST** use Named Credentials/External Credentials.

---

### LWC Standards

#### Component Architecture

- Components **SHOULD** follow smart/dumb separation:
  - Smart/container components handle data orchestration.
  - Dumb/presentational components render state and emit events.
- Reusable UI components **MUST** keep business logic minimal.

#### Data Access Patterns

- Prefer LDS/UI API for standard CRUD where feasible.
- Use `@wire` for reactive reads and cache-friendly retrieval.
- Use imperative Apex only for explicit user actions or non-reactive logic.

#### Error Handling

- Components **MUST** handle loading, empty, success, and error states.
- Errors **SHOULD** be normalized and displayed with actionable messaging.
- Sensitive exception details **MUST NOT** be exposed to end users.

#### Performance

- Minimize re-renders and expensive computed work.
- Batch UI updates where possible.
- Avoid unnecessary Apex round trips when LDS/UI API can satisfy requirements.

#### Security

- UI checks **MUST NOT** replace server-side authorization.
- Apex controllers called by LWC **MUST** enforce CRUD/FLS per Security Model.

#### Testing Strategy

- Jest tests **SHOULD** cover rendering states, event contracts, and error behavior.
- Use mocks for Apex methods and wire adapters.

---

### Metadata Standards

#### Objects & Fields

- Custom objects **MUST** include clear descriptions and ownership.
- Fields **MUST** define data type, help text, and security classification.
- Required fields **SHOULD** be required by business necessity, not convenience.
- High-cardinality lookup/filter fields **SHOULD** be evaluated for index strategy.

#### Record Types & Layouts

- Record types **MUST** represent materially different business processes.
- Layout assignment **MUST** align with profiles/permsets strategy.
- Layout changes **SHOULD** avoid duplicating conditional logic that belongs in Dynamic Forms/Flow.

#### Validation Rules

- Validation rules **MUST** include user-friendly, actionable messages.
- Bypass logic **MUST NOT** rely on hidden hardcoded profile names.
- Any bypass mechanism **MUST** be explicit (e.g., controlled custom permission).

#### Flows

- Flow metadata **MUST** include version notes and clear descriptions.
- Record-triggered flow design **MUST** follow Flow Standards.

#### Permission Sets / PSGs

- Access grants **MUST** be permission-set centric, not profile-centric.
- PSGs **SHOULD** represent role bundles and remain minimal.
- Use muting permission sets where needed to reduce overgranting.

#### Custom Metadata

- Business configuration **SHOULD** be stored in Custom Metadata, not hardcoded in Apex.
- Custom Metadata records **MUST** have deterministic developer names.

#### External IDs & Indexes

- Integration key fields **MUST** use External ID where appropriate.
- Query patterns for high-volume objects **MUST** be selective.
- If performance issues are expected, document index requests early.

---

### Integration Standards

#### Authentication and Endpoint Management

- HTTP callouts **MUST** use Named Credentials with External Credentials where applicable.
- Endpoints, tokens, client secrets, and API keys **MUST NOT** be hardcoded.
- Integration settings **SHOULD** be metadata-driven (Custom Metadata) for non-secret config.

#### Contract and Versioning

- API contracts **MUST** be documented (request/response, status handling, retries).
- Integrations **SHOULD** include explicit versioning strategy.
- Breaking contract changes **MUST** trigger consumer impact review.

#### Reliability

- Callout flows **SHOULD** support idempotency keys when provider supports it.
- Retries **MUST** avoid duplicate side effects (idempotent design required).
- Failures **MUST** route to structured logging and alerting paths.

#### Apex Implementation Guidance

- Use dedicated client classes per external system.
- Parse and validate external payloads defensively.
- Map provider errors into domain-level exceptions.

#### Data Security

- PII-sensitive payload fields **MUST** be minimized and redacted in logs.
- Outbound data sets **MUST** obey least-data principles.

---

### Testing Standards

#### Apex Testing Principles

- Tests **MUST** use AAA (Arrange, Act, Assert).
- Tests **MUST** be deterministic and isolated.
- `SeeAllData=true` **MUST NOT** be used by default.
- Shared test data **SHOULD** come from a test data factory.

#### Required Test Scenarios

- Happy path behavior.
- Negative/error path behavior.
- Bulk behavior with up to 200 records.
- Async behavior (`Queueable`, `Future`, `Batch`, scheduled).
- Security-sensitive behavior where relevant.

#### Callout Testing

- HTTP callouts **MUST** use `HttpCalloutMock` (or equivalent mock pattern).
- Tests **MUST NOT** depend on real endpoints.
- Named Credential usage **SHOULD** be abstracted to allow mock isolation.

#### Coverage Policy

- Salesforce platform requirement is **75% overall Apex coverage**.
- Team-level target **MAY** be higher by policy.
- Coverage without assertions is insufficient and should be rejected.

#### LWC Testing Strategy

- LWC Jest tests **SHOULD** validate rendering, events, and error states.
- Prefer testing component behavior over private implementation details.

#### Flow Testing Strategy

- Validate entry criteria, branch paths, and fault handling.
- Validate flow-triggered side effects and idempotency.
- Use Apex tests where necessary to verify flow-invoked Apex.

---

### Deployment & Release Standards

#### Dependency Ordering

Deploy metadata in this order unless a justified exception exists:

1. Objects
2. Fields
3. Record Types
4. Layouts / FlexiPages
5. Flows / Validation Rules / Automation metadata
6. Apex / LWC / Aura
7. Permission Sets / Permission Set Groups

#### Package Manifest Strategy

- `package.xml` **SHOULD** be used for deterministic, reviewable deploy scopes.
- Manifest files **MUST** include only required components for each release unit.
- Large releases **SHOULD** be split into coherent deployment waves.

#### Validation Commands

Use validation-first release flow in CI/CD and pre-prod checks:

```bash
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org <alias> \
  --check-only \
  --test-level RunLocalTests \
  --wait 60

sf project deploy report --use-most-recent --target-org <alias>
```

For production quick deploy after successful validation:

```bash
sf project deploy quick --job-id <validatedJobId> --target-org <prodAlias>
```

#### Destructive Changes Policy

- Destructive changes **MUST** be explicitly approved.
- Destructive manifests **MUST** be isolated, reviewed, and reversible.
- Rollback/restore strategy **MUST** be documented before execution.

#### Release Quality Gates

- Security review items resolved.
- Tests pass with required coverage.
- Integration dependencies confirmed.
- Post-deploy smoke tests defined and executed.

---

### Observability & Logging Standards

#### Logging Principles

- Logs **MUST** support diagnosis without exposing secrets or sensitive data.
- Critical business events **MUST** include correlation identifiers.
- Error logs **MUST** include actionable context: operation, entity key, and failure class.

#### Event Taxonomy

- **Audit events**: security-relevant state changes.
- **Business events**: domain milestones and SLA markers.
- **Technical events**: retries, queue failures, integration exceptions.

#### Implementation Patterns

- Use centralized logging helpers in Apex.
- For asynchronous paths, include job IDs and parent transaction identifiers.
- For Flow fault paths, capture fault source and input context summary.

#### Alerting and Operations

- Repeated integration failures **MUST** trigger alerts.
- High-severity automation faults **SHOULD** notify support channels.
- Dashboards **SHOULD** track flow fault rate, async backlog, and integration latency.

---

## Part 2: Code Examples

### Apex Examples

#### Bulk-safe Trigger Handler Skeleton

```apex
trigger ClientProfileTrigger on Client_Profile__c 
    (before insert, before update, after update) {
    FT_ClientProfileTriggerHandler.run(
        Trigger.operationType,
        Trigger.new,
        Trigger.oldMap
    );
}

public with sharing class FT_ClientProfileTriggerHandler {
    private static Boolean isRunning = false;

    public static void run(
        System.TriggerOperation op, 
        List<Client_Profile__c> newList, 
        Map<Id, Client_Profile__c> oldMap
    ) {
        if (isRunning) return; // recursion guard
        isRunning = true;
        try {
            if (op == System.TriggerOperation.BEFORE_UPDATE) {
                FT_ClientProfileService.applyBusinessRules(newList, oldMap);
            }
        } finally {
            isRunning = false;
        }
    }
}
```

#### CRUD/FLS Guard Pattern

```apex
public with sharing class FT_ClientProfileService {
    public static void updateGoal(Id clientId, String goal) {
        if (!Schema.sObjectType.Client_Profile__c.isUpdateable()) {
            throw new SecurityException('No object update access');
        }

        List<Client_Profile__c> rows = [
            SELECT Id, Goal__c
            FROM Client_Profile__c
            WHERE Id = :clientId
            LIMIT 1
        ];

        rows[0].Goal__c = goal;
        update rows;
    }
}
```

#### Callout via Named Credential

```apex
public with sharing class FT_RemoteProgramClient {
    public static HttpResponse sendProgram(String payloadJson) {
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('callout:ProgramApi/v1/programs');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payloadJson);
        return new Http().send(req);
    }
}
```

**Important**: Never hardcode full URLs or tokens. Use Named Credentials + External Credentials.

---

### LWC Examples

#### Smart + Dumb Component Pattern

```js
// smart container: ftClientDashboardContainer.js
import { LightningElement, wire } from "lwc";
import getDashboard from "@salesforce/apex/FT_ClientDashboardController.getDashboard";

export default class FtClientDashboardContainer extends LightningElement {
    state = { data: null, error: null };

    @wire(getDashboard)
    wiredDashboard({ data, error }) {
        if (data) this.state = { data, error: null };
        if (error) this.state = { data: null, error };
    }
}
```

```html
<!-- dumb presentational: ftClientDashboardView.html -->
<template>
    <template lwc:if="{data}">
        <!-- render only -->
    </template>
    <template lwc:elseif="{error}">
        <c-error-panel message="Unable to load dashboard"></c-error-panel>
    </template>
    <template lwc:else>
        <lightning-spinner></lightning-spinner>
    </template>
</template>
```

#### Jest Strategy Notes

- Test loading, success, empty, and error render states.
- Mock wire adapters and Apex modules.
- Assert emitted events and public contract behavior.

---

### Flow Examples

#### Before-Save Flow Use Case

**Name**: `ClientProfile_BeforeSave_RecordTriggered`

- **Trigger**: before create/update on `Client_Profile__c`
- **Purpose**: set derived fields on same record only
- **No DML** on related objects
- **No callouts**

#### After-Save Flow Use Case

**Name**: `TrainingSession_AfterSave_RecordTriggered`

- **Trigger**: after create/update on `Training_Session__c`
- **Purpose**: create follow-up tasks and publish notifications
- **Uses** invocable Apex for external sync enqueue
- **Fault paths** route to logging action/subflow

#### Fault Path Pattern

For each create/update/action element:
- Connect fault path to a logging subflow
- Capture: flow name, record id, element API name, fault message
- Optionally notify support channel

---

### Metadata Examples

#### Validation Rule Naming

- `VR_ClientProfile_GoalDateRequired`
- `VR_TrainingSession_EndAfterStart`

#### Flow Naming

- `ClientProfile_BeforeSave_RecordTriggered`
- `TrainerAssignment_AfterSave_RecordTriggered`
- `ProgramSync_Autolaunched_Subflow`

#### Custom Metadata Pattern

- **Type**: `CMDT_Integration_Config__mdt`
- **Records**:
  - `ProgramApi_Default`
  - `ProgramApi_Sandbox`

Use custom metadata for non-secret settings (timeouts, feature toggles, endpoint suffixes).

#### Permission Set Naming

- `PS_FT_Admin`
- `PS_FT_Trainer`
- `PS_FT_ReadOnly`

#### PSG Composition Example

`PSG_FT_Trainer` includes:
- `PS_FT_Trainer`
- `PS_FT_ReadOnly`
- Optional muting permission set to remove sensitive permissions for specific cohorts.

---

### Deployment Examples

#### Validate a Manifest in Target Org

```bash
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org UAT \
  --check-only \
  --test-level RunLocalTests \
  --wait 60
```

#### Quick Deploy After Validation

```bash
sf project deploy quick --job-id 0AfXXXXXXXXXXXX --target-org PROD
```

#### Destructive Change Sequence

1. Backup metadata + confirm rollback artifact.
2. Validate additive deployment first.
3. Run approved destructive deployment in separate change set/manifest.
4. Execute post-deploy smoke tests.

---

## Part 3: Quick Reference Checklists

### Pre-Implementation Checklist

- [ ] Scope is clearly defined (objects, flows, classes, metadata).
- [ ] Security implications reviewed (CRUD/FLS, user/system mode).
- [ ] Integration dependencies identified.
- [ ] Impact on existing automation assessed (triggers, flows).
- [ ] Naming conventions aligned.
- [ ] Rollback strategy considered.

### Code Review Checklist

- [ ] Implementation follows stated plan.
- [ ] All code references applicable standards.
- [ ] No hardcoded endpoints, secrets, or credentials.
- [ ] CRUD/FLS checks present at entry points.
- [ ] Bulk-safe logic (handles 200+ records).
- [ ] Recursion/idempotency guards in place.
- [ ] Fault handling in flows/callouts.
- [ ] Logging/observability for critical paths.
- [ ] Tests: AAA pattern, mocked callouts, SeeAllData=false.
- [ ] Definition of Done satisfied.

### Deployment Checklist

- [ ] Manifest reviewed and dependency order correct.
- [ ] Validation deployment successful.
- [ ] Test coverage meets 75% minimum (Salesforce) or team target.
- [ ] Security review complete.
- [ ] Integration dependencies confirmed.
- [ ] Rollback plan documented.
- [ ] Post-deploy smoke tests defined.
- [ ] Destructive changes (if any) isolated and approved.

---

## Part 4: Common Patterns & Anti-Patterns

### ✅ DO

| Pattern | Benefit |
|---------|---------|
| Use one trigger per object with handler delegation | Easier to manage recursion guards |
| Implement CRUD/FLS checks at entry points | Prevents unauthorized data access |
| Use Named Credentials for callouts | Secure credential management |
| Centralize business logic in service/domain classes | Reusability and testability |
| Include fault paths on all Flow actions | Prevents silent failures |
| Use custom metadata for config | Centralized, updatable configuration |
| Implement idempotency checks | Safe for retries and duplicate invocations |
| Document security decisions (user vs system mode) | Clarity for reviewers and maintainers |

### ❌ DON'T

| Anti-Pattern | Risk |
|--------------|------|
| Hardcode endpoints, tokens, or API keys | Security breach |
| Use `SeeAllData=true` by default in tests | False confidence in test coverage |
| Place business logic in triggers or LWC directly | Difficult to test and maintain |
| Perform DML inside loops unbounded by collection size | Limit violations, poor performance |
| Chain multiple flows without clear ownership | Hard to debug, difficult to change |
| Skip fault paths in flows | Silent automation failures |
| Use system mode without compensating controls | Privilege escalation risk |
| Leave secrets in version control | Security breach exposure |

---

## Part 5: Troubleshooting Guide

### "RecursionException: maximum stack depth exceeded"

**Cause**: Trigger/Flow infinite loop.  
**Solution**: Add recursion guard to trigger handler, implement idempotency checks in flows, use change-detection filters.

### Integration test failures with "Callout exception"

**Cause**: Attempting real HTTP callout in test.  
**Solution**: Use `@isTest(SeeAllData=false)` and mock with `HttpCalloutMock`. Abstract Named Credentials usage to allow test injection.

### "CRUD/FLS Check Failed"

**Cause**: Missing or incorrect security checks.  
**Solution**: Add `Schema.sObjectType.<Object>.isCreateable()`, `Schema.getGlobalDescribe().get('<Object>').getDescribe().fields.getMap().get('<Field>').isAccessible()` checks.

### "Flow Fault Not Logged"

**Cause**: Missing fault path or inadequate logging.  
**Solution**: Connect fault path to logging subflow, include record ID, element API name, and fault message in logs.

### "Deployment Validation Failed: Unexpected Argument"

**Cause**: Incorrect manifest order or circular dependencies.  
**Solution**: Review deployment order (objects → fields → layouts → flows → apex → permsets). Check for missing dependencies.

---

## Part 6: Project Setup

### Using the DevTemplate

A PowerShell script automates project setup:

```powershell
# Create a new Salesforce project with DevTemplate standards
C:\DevTemplates\sfai.ps1 -ProjectName MyProject -BaseDir C:\Projects
```

This script:
1. Creates an SFDX project
2. Initializes `manifest/package.xml`
3. Copies `salesforce-ai-pack` documentation into the project

### Manual Integration

Copy `salesforce-ai-pack/docs/ai/*` contents into your repo's `docs/ai/` folder for reference during development.

---

## Part 7: Integration with Copilot/Claude

### Example Prompt: "Add a new feature"

```
I need to add a new feature to track training sessions.

Scope:
- Custom object: Training_Session__c
- Existing object: Client_Profile__c (lookup)
- Need after-save flow to create follow-up tasks
- LWC dashboard to display sessions

Use the Salesforce AI-Assisted Development standards from this guide.

Process:
1) Plan: list files to create/modify and architectural decisions
2) Diff: show exactly what changes
3) Implement: provide code
4) Tests: describe test strategy and commands
5) Deploy: validation and deployment commands
```

### Example Prompt: "Review this code for standards compliance"

```
Review this Apex class against the standards:
- Agent Rules: dos/don'ts
- Apex Standards: bulk safety, CRUD/FLS, naming
- Security Model: user mode vs system mode, secrets
- Integration Standards: (if applicable)

Flag specific standard violations and suggest fixes.
Include a Definition of Done checklist for this change.
```

### Example Prompt: "Create deployment plan"

```
I have the following changes ready:
- 3 new custom fields
- 2 new Apex classes with tests
- 1 after-save record-triggered flow
- Permission set updates

Create a deployment package.xml in dependency order.
Provide validation and deployment Salesforce CLI commands.
Include rollback strategy.
```

---

## Part 8: Reference Index

### Standards Documents

| Standard | Focus |
|----------|-------|
| **Agent Rules** | AI agent governance, execution contracts |
| **Definition of Done** | Completeness checklist for all changes |
| **Architecture** | Layering, separation of concerns, trigger+flow interaction |
| **Naming Conventions** | Class, field, flow, permission set naming patterns |
| **Security Model** | CRUD/FLS, user vs system mode, credential handling |
| **Apex Standards** | Trigger handlers, DML patterns, bulk safety |
| **Flow Standards** | Before/after save, fault paths, idempotency |
| **LWC Standards** | Component architecture, data access, testing |
| **Metadata Standards** | Objects, fields, record types, PSGs, custom metadata |
| **Integration Standards** | Callouts, endpoints, retry logic, data security |
| **Testing Standards** | AAA pattern, coverage policy, mock strategies |
| **Deployment & Release** | Manifest order, validation, rollback, destructive changes |
| **Observability & Logging** | Event taxonomy, logging patterns, alerting |

---

## Notes

- **Version**: 2.0 (Feb 2026)
- **Team Prefix**: `FT_` (example for Apex classes, flows, metadata)
- **Coverage Minimum**: 75% (Salesforce platform) or team policy
- **Bulk Test Size**: 200 records
- **Key Principle**: Plan → Diff → Implement → Test → Deploy with standards enforcement

---

**For questions or clarifications**, refer to the specific standard sections above or ask Copilot to cite the relevant standard during implementation.

---

## Part 9: Website_CX_Agent_V6 (v2) Research Snapshot

### Scope and Evidence

- **Analysis Date**: March 5, 2026
- **Primary evidence files**:
  - `temp-agent-audit-package.xml`
  - `artifacts-v6-audit/transcript.json`
  - `artifacts-v6-audit/command-discovery.json`
  - `force-app/main/default/bots/Website_CX_Agent_V5/*`
  - `force-app/main/default/genAiPlannerBundles/Website_CX_Agent_V5/Website_CX_Agent_V5.genAiPlannerBundle`
  - `force-app/main/default/flows/*v2.flow-meta.xml`
  - `force-app/main/default/classes/FLO_CasePicklistDependencyMatrixActionV2.cls`

### Target Inventory Requested for `Website_CX_Agent_V6 - v2`

From `temp-agent-audit-package.xml`:

| Metadata Type | Member |
|---|---|
| Bot | `Website_CX_Agent_V6` |
| GenAiPlannerBundle | `Website_CX_Agent_V6` |
| GenAiPlugin | `Support_Case_Creation_v2` |
| GenAiFunction | `Send_Verification_Code_FLO_v2` |
| GenAiFunction | `Verify_Email_And_Find_Contact_FLO_v2` |
| GenAiFunction | `Create_Contact_Records_FLO_v2` |
| GenAiFunction | `Get_Case_Picklist_Values_FLO_v2` |
| GenAiFunction | `Create_Support_Case_FLO_v2` |

### Repository Presence Check (Current State)

| Target Member | Present in `force-app` |
|---|---|
| `Website_CX_Agent_V6` (Bot) | No |
| `Website_CX_Agent_V6` (GenAiPlannerBundle) | No |
| `Support_Case_Creation_v2` (GenAiPlugin) | No |
| `Send_Verification_Code_FLO_v2` (GenAiFunction) | No |
| `Verify_Email_And_Find_Contact_FLO_v2` (GenAiFunction) | No |
| `Create_Contact_Records_FLO_v2` (GenAiFunction) | No |
| `Get_Case_Picklist_Values_FLO_v2` (GenAiFunction) | No |
| `Create_Support_Case_FLO_v2` (GenAiFunction) | No |

### Closest Implemented Agent Chain in Source (V5 Baseline)

**Entry Metadata**
- Bot: `force-app/main/default/bots/Website_CX_Agent_V5/Website_CX_Agent_V5.bot-meta.xml`
- Bot version: `force-app/main/default/bots/Website_CX_Agent_V5/v1.botVersion-meta.xml`
- Planner bundle: `force-app/main/default/genAiPlannerBundles/Website_CX_Agent_V5/Website_CX_Agent_V5.genAiPlannerBundle`

**Planner Topics and Action Targets**

| Topic | Local Action | Invocation Target | Target Type |
|---|---|---|---|
| `GeneralFAQ` | `AnswerQuestionsWithKnowledge` | `streamKnowledgeSearch` | standardInvocableAction |
| `Support_Case_Creation` | `FLO_SendVerificationCode` | `Send_Verification_code_to_Customers_Email` | flow |
| `Support_Case_Creation` | `FLO_VerifyEmailAndFindContact` | `VerifyEmailAndFindContact` | flow |
| `Support_Case_Creation` | `FLO_CreateContactRecords` | `Check_Contact_Records` | flow |
| `Support_Case_Creation` | `FLO_GetCasePicklistValues` | `CasePicklistDependencyMatrixAction` | apex |
| `Support_Case_Creation` | `FLO_CreateSupportCase` | `Create_Support_Case` | flow |

**Important Mapping Behavior (V5 Planner)**
- `endUserEmail` is reused across send/verify/create-contact actions.
- `authenticationKey` and `verificationCode` are persisted between steps.
- `output_ContactRecordId` maps into `VerifiedCustomerId`.
- `RoutableId` (context variable) maps to `input_messagingSessionID`.
- `output_caseNumber` maps to conversation variable `caseNumber`.

### v2 Backend Components Found in Source (Likely V6-v2 Implementations)

The V6-v2 metadata members are not present, but v2 backend implementations do exist and align semantically to requested function names.

| Requested V6-v2 Function | Local Implementation Candidate | Status |
|---|---|---|
| `Send_Verification_Code_FLO_v2` | `flows/FLO_SendVerificationCode_v2.flow-meta.xml` | Present |
| `Verify_Email_And_Find_Contact_FLO_v2` | `flows/FLO_VerifyEmailAndFindContact_v2.flow-meta.xml` | Present |
| `Create_Contact_Records_FLO_v2` | `flows/FLO_CreateContactRecords_v2.flow-meta.xml` | Present |
| `Get_Case_Picklist_Values_FLO_v2` | `classes/FLO_CasePicklistDependencyMatrixActionV2.cls` | Present |
| `Create_Support_Case_FLO_v2` | `flows/FLO_CreateSupportCase_v2.flow-meta.xml` | Present |

### v2 Function-Level Dependency Details

#### 1) `FLO_SendVerificationCode_v2`
- Type: Auto-launched flow (API 66.0, Active)
- Input variables: `endUserEmail`
- Output variables: `authenticationKey`, `status`, `outMessage`
- Platform actions used:
  - `generateVerificationCode`
  - `emailSimple`

#### 2) `FLO_VerifyEmailAndFindContact_v2`
- Type: Auto-launched flow (API 66.0, Active)
- Input variables: `authenticationKey`, `endUserEmail`, `verificationCode`
- Output variables: `isVerified`, `verifiedContactId`, `status`, `outMessage`
- Platform action used: `verifyCustomerCode`
- Data dependency:
  - Lookup `Contact` by `Email`

#### 3) `FLO_CreateContactRecords_v2`
- Type: Auto-launched flow (API 66.0, Active)
- Input variables: `customerName`, `endUserEmail`, `existingContactId`, `isVerified`, `phoneNumber`
- Output variables: `contactId`, `status`, `outMessage`
- Data dependencies:
  - Lookup `Contact` by `Email`
  - Lookup `RecordType` where `SobjectType = Account`, `DeveloperName = PersonAccount`, `IsActive = true`
  - Create `Account` and read `PersonContactId` for contact output

#### 4) `FLO_CasePicklistDependencyMatrixActionV2` (Apex)
- Invocable label: `FLO Get Case Picklist Values v2`
- Input contract:
  - `isVerified` must be true
  - `requestKey` must be `classification`
- Output contract: `matrixJson`, `status`, `outMessage`
- Data dependencies:
  - `Case_ClientType_EntryCategory__mdt` (`IsActive__c = true`)
  - `Case_EntryCategory_SubEntryCategory__mdt` (`IsActive__c = true`)
- Related test: `classes/FLO_CasePicklistMatrixV2Test.cls`

#### 5) `FLO_CreateSupportCase_v2`
- Type: Auto-launched flow (API 66.0, Active)
- Input variables: `contactId`, `customerType`, `entryCategory`, `subEntryCategory`, `caseSubject`, `caseDescription`, `draftConfirmed`, optional `assetName`, optional `invoiceNumber`
- Output variables: `caseId`, `caseNumber`, `status`, `outMessage`
- Data dependencies:
  - Lookup `Contact` by `Id`
  - Lookup `RecordType` where `SobjectType = Case`, `DeveloperName = CX`, `IsActive = true`
  - Optional lookup `Asset` by `Name`
  - Create `Case` with fields including:
    - `Client_Type__c`
    - `Entry_Category__c`
    - `Sub_Entry_Category__c`
    - `Divalto_Invoice_Number__c`
    - `Origin = Website Agent`
    - `RecordTypeId`, `ContactId`, `AccountId`, `AssetId`, `Subject`, `Description`

### How the Agent Is Written (Authoring Analysis)

Observed writing patterns in planner/plugin/topic metadata:

1. **Strict stage-gated orchestration**
- Instructions enforce ordered execution with explicit “do not skip/reorder” rules.
- Verification and identity steps are hard prerequisites before case creation.

2. **High-control response behavior**
- Instructions repeatedly force single final responses per turn.
- Draft/intermediate output is explicitly prohibited.

3. **Knowledge-first fallback design**
- General FAQ topic is constrained to knowledge-based answers.
- Escalation path transitions to structured support-case flow only when unresolved.

4. **Variable-driven determinism**
- Topic behavior depends heavily on conversation variables (`isVerified`, `VerifiedCustomerId`, `picklistMatrixJson`, `caseNumber`).
- Planner attribute mappings are central to correctness.

5. **Safety and consistency intent**
- Anti-hallucination rules (“knowledge only”, no simulated action results).
- Case confirmation messaging is standardized after successful case number return.

### Gaps and Risks Identified

- V6-v2 metadata set is requested but not present in source control (`Bot`, `PlannerBundle`, `Plugin`, `GenAiFunction` members).
- Current wired planner (`Website_CX_Agent_V5`) still targets older flow/Apex names (`Create_Support_Case`, `VerifyEmailAndFindContact`, `Check_Contact_Records`, `CasePicklistDependencyMatrixAction`).
- v2 backend assets exist but are not yet linked by corresponding v2 `GenAiFunction` and `GenAiPlugin` metadata in this repo.
- `artifacts-v6-audit/transcript.json` confirms CLI preview could not run because Agentforce CLI plugin commands were unavailable (`@salesforce/plugin-agent` missing).

### Recommended Documentation Baseline for V6-v2

For future V6-v2 commits, require all of the following in source together:
- `bots/Website_CX_Agent_V6/*`
- `genAiPlannerBundles/Website_CX_Agent_V6/*`
- `genAiPlugins/Support_Case_Creation_v2.genAiPlugin-meta.xml`
- `genAiFunctions/*_v2/*.genAiFunction-meta.xml` for all five v2 functions
- Explicit invocation targets that point to v2 flow/Apex implementations

