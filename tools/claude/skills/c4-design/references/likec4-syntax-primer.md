# Likec4 Syntax Primer

Quick reference for the DSL used by this skill. **Canonical docs at https://likec4.dev/docs/dsl** — when in doubt, fetch the latest grammar from there rather than trusting this primer (the DSL evolves).

This primer targets Likec4 1.x. Validate every DSL change with `npx @likec4/cli validate <file>.c4`.

## File Structure

A `.c4` file has three top-level blocks, in order:

```
specification {
  // declare element kinds and their visual styles
}

model {
  // instantiate elements and define relationships
}

views {
  // define which slice of the model to render
}
```

## Specification

Declare the kinds of elements your model will use. Common kinds:

```c4
specification {
  element actor {
    style {
      shape person
      color secondary
    }
  }

  element externalSystem {
    style {
      shape rectangle
      color muted
    }
  }

  element system

  element container {
    style {
      shape rectangle
    }
  }

  element component {
    style {
      shape rectangle
    }
  }
}
```

You can also declare tags (`tag legacy`, `tag experimental`) and relationship kinds. Most projects don't need either at v0.1.

## Model

Instantiate the elements and wire up relationships:

```c4
model {
  // External actors
  customer = actor 'Customer' {
    description 'End user buying things'
  }

  operator = actor 'Operator' {
    description 'Internal staff managing the catalog'
  }

  // External systems
  stripe = externalSystem 'Stripe' {
    description 'Payments and refunds'
  }

  anthropic = externalSystem 'Anthropic API' {
    description 'LLM inference for recommendations'
  }

  // The system being designed
  shop = system 'Shop' {
    description 'The e-commerce platform we are building'

    // Containers
    web = container 'Web App' {
      technology 'Next.js, TypeScript'
      description 'Customer-facing storefront'
    }

    api = container 'API' {
      technology 'Node.js, Fastify'
      description 'Application API used by web and admin clients'

      // Components inside this container
      auth = component 'Auth Handler' {
        description 'Token issuance and validation'
      }

      catalog = component 'Catalog Service' {
        description 'Product CRUD and search'
      }

      checkout = component 'Checkout Orchestrator' {
        description 'Coordinates cart -> payment -> fulfillment'
      }
    }

    db = container 'PostgreSQL' {
      technology 'PostgreSQL 16'
      description 'Application database'
    }

    worker = container 'Worker' {
      technology 'Node.js'
      description 'Background jobs and webhook handlers'
    }
  }

  // Relationships
  customer -> web 'Browses, buys'
  operator -> web 'Admin operations'
  web -> api 'HTTPS/JSON'
  api.auth -> db 'Reads/writes users'
  api.catalog -> db 'Reads/writes products'
  api.checkout -> stripe 'Charges, refunds'
  worker -> anthropic 'Recommendation inference'
  stripe -> worker 'Webhook events'
}
```

Notes:

- Element IDs (`customer`, `web`, `api`) are lowercase, no spaces, used for references.
- Display names (`'Customer'`, `'Web App'`) are human-readable strings.
- Nested elements (components inside containers) are referenced with dot notation: `api.auth`, `api.catalog`.
- Edges (`->`) have an optional label string. Keep labels to verb phrases or protocols.

## Views

Define what slice of the model to render in each diagram:

```c4
views {
  view index {
    title 'System Context'
    description 'Customers and operators talking to the shop'
    include *  // include everything in the top-level scope
  }

  view containers of shop {
    title 'Containers'
    description 'Deployable units of the shop system'
    include *
  }

  view api_components of api {
    title 'API Components'
    description 'Internal modules of the API container'
    include *
  }
}
```

The `of <element>` clause scopes the view to descendants of that element. `include *` means "every direct child and its outgoing edges." More granular control:

```c4
view selective {
  include customer, web, api
  include api.auth, api.checkout
  exclude api.catalog
}
```

## Validation

```bash
npx @likec4/cli validate docs/c4/model.c4
```

Exits 0 on success, prints errors with line numbers on failure.

## Building the Dashboard

```bash
npx @likec4/cli build --src docs/c4 --output docs/c4/dashboard
```

Outputs a static HTML site at `docs/c4/dashboard/`. Open `index.html` in a browser.

(See `scripts/build-dashboard.sh` for the version the skill actually invokes.)

## Things This Primer Does NOT Cover

- Custom styles, themes, colors (`style { ... }` blocks beyond the basics)
- Tags and tag-based view filtering
- Relationship kinds and their styles
- Deployment views (Likec4 also supports a deployment level beyond components)
- Dynamic views (sequence-diagram-style ordered interactions)
- LikeC4's TypeScript/React integration (`@likec4/react` if you want to embed views in a docs site)

For any of these, fetch https://likec4.dev/docs and read the relevant section. The DSL grammar there is authoritative.

## Common Errors

| Error | Fix |
|---|---|
| `Element 'X' not found` in an edge | The element ID was misspelled or the element is in a different scope. Use full dot path: `api.auth`, not just `auth`. |
| `Duplicate element ID` | Same ID declared twice in the same scope. Element IDs are unique within their parent. |
| `Unexpected token` near a `view` | Missing closing brace on the previous element, or missing `of <scope>` clause. |
| Dashboard renders blank for a view | The view's `include` clause matches nothing. Try `include *` first, then narrow. |
| All elements show the same color | Specification missing `style { color ... }` blocks. Add styles to the `element` declarations. |
