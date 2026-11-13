## ADDED Requirements

### Requirement: Single requirements authority

The repository MUST use OpenSpec as its only requirements pipeline. Active
change artifacts MUST live under `openspec/changes/`; the constitution MUST live
at `openspec/constitution.md`. Repository prompts MUST NOT create or customize
retired workflow assets.

#### Scenario: Contributor prepares a change
- **GIVEN** a contributor following repository guidance
- **WHEN** they prepare and implement a non-trivial change
- **THEN** they use OpenSpec proposal, design, specs, and tasks with the constitution
- **AND** no numbered feature workflow or retired command is required

#### Scenario: Contributor customizes project instructions
- **GIVEN** the repository's initialization customization command
- **WHEN** a contributor follows its instructions
- **THEN** it configures only the retained OpenSpec requirements workflow
- **AND** it does not delete existing user files

### Requirement: Historical artifact preservation

Finished strategic artifacts MUST be retained under `openspec/changes/archive/`
with original substantive text and task states preserved. Retired terminology
and paths MUST be reworded neutrally. New completion claims MUST have evidence;
unproven open tasks MUST remain open and be marked unverified.

#### Scenario: Contributor reads the initial container design
- **GIVEN** the archived initial-containerfile artifacts
- **WHEN** a contributor reviews historical requirements and task states
- **THEN** the original content and 23 existing checked task states remain available
- **AND** appended evidence links to the merged implementation PR without asserting a fresh runtime verification
