1. 幫助我編輯ai-coding-skill-uc這個skill
2. 我需要改變get_product相關的usecase，目前回傳使用dto的物件，請幫我修改成readonly entity，以下為他的描述:
# Read-only Entities Pattern

## Intent

Protect aggregate integrity by exposing internal entities as read-only objects.

When an Aggregate needs to return an Entity to external clients, it should not expose the original mutable Entity directly. Instead, return a read-only version that keeps the same domain concept while preventing unauthorized state changes.

## Problem

In Domain-Driven Design (DDD), clients should interact with an Aggregate only through its Aggregate Root.

However, if the Aggregate Root returns references to internal Entities, clients may keep those references and modify the Entities directly, bypassing the Aggregate Root and breaking business rules or invariants.

## Solution

Create a Read-only Entity that represents a restricted version of the original Entity:

- Keep query operations available.
- Block command operations that modify state.
- Convert nested returned Entities into Read-only Entities.
- Return immutable collections when exposing Entity collections.

The Aggregate Root should always convert internal Entities into Read-only Entities before returning them.

## Implementation Approaches

### 1. Inheritance (Special Case)

Create a subclass of the Entity:

- Override state-changing methods to throw exceptions.
- Reuse safe query methods.
- Override queries returning Entities or collections to return read-only versions.

### 2. Composition (Proxy)

Create a wrapper around the Entity:

- Store the original Entity internally.
- Delegate read operations.
- Reject modification operations.

## Benefits

- Preserves Aggregate encapsulation.
- Prevents external clients from modifying internal state.
- Keeps the returned object aligned with the domain model.
- Provides immediate feedback when invalid modifications are attempted.

3. 請把整個skill中使用dto的地方都改成readonly entity
4. 幫我修改AI Coding Exercise Skills UC，在使用readonly時需要確保沒有違反CA的跨層原則，如果違反，需要使用DtO彌補outport