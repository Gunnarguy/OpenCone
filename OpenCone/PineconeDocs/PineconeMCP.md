# Use the Pinecone MCP server

> Use Pinecone MCP server for AI agent integration.

<Note>
  This feature is in [early access](/release-notes/feature-availability) and is not intended for production usage.
</Note>

The Pinecone MCP server enables AI agents to interact directly with Pinecone's functionality and documentation via the standardized [Model Context Protocol (MCP)](https://modelcontextprotocol.io/). Using the MCP server, agents can search Pinecone documentation, manage indexes, upsert data, and query indexes for relevant information.

This page shows you how to configure [Cursor](https://www.cursor.com/) and [Claude Desktop](https://claude.ai/download) to connect with the Pinecone MCP server.

## Tools

The Pinecone MCP server provides the following tools:

* `search-docs`: Search the official Pinecone documentation.
* `list-indexes`: Lists all Pinecone indexes.
* `describe-index`: Describes the configuration of an index.
* `describe-index-stats`: Provides statistics about the data in the index, including the  number of records and available namespaces.
* `create-index-for-model`: Creates a new index that uses an integrated inference model to embed text as vectors.
* `upsert-records`: Inserts or updates records in an index with integrated inference.
* `search-records`: Searches for records in an index based on a text query, using integrated inference for embedding. Has options for metadata filtering and reranking.
* `cascading-search`: Searches for records across multiple indexes, deduplicating and reranking the results.
* `rerank-documents`: Reranks a collection of records or text documents using a specialized reranking model.

<Note>
  The Pinecone MCP supports only [indexes with integrated embedding](/guides/index-data/indexing-overview#vector-embedding). Indexes for vectors you create with external embedding models are not supported.
</Note>

## Before you begin

Ensure you have the following:

* A [Pinecone API key](https://app.pinecone.io/organizations/-/keys)
* [Node.js](https://nodejs.org/en) installed, with `node` and `npx` available on your `PATH`

## Configure Cursor

<Steps>
  <Step title="Add the MCP server">
    In your project root, create a `.cursor/mcp.json` file, if it doesn't exist, and add the following configuration:

    ```json  theme={null}
    {
      "mcpServers": {
        "pinecone": {
          "command": "npx",
          "args": [
            "-y", "@pinecone-database/mcp"
          ],
          "env": {
            "PINECONE_API_KEY": "YOUR_API_KEY"
          }
        }
      }
    }
    ```

    Replace `YOUR_API_KEY` with your Pinecone API key.
  </Step>

  <Step title="Check the status">
    Go to **Cursor Settings > MCP**. You should see the server and its list of tools.
  </Step>

  <Step title="Add Pinecone rules">
    The Pinecone MCP server works well out-of-the-box. However, you can add explicit rules to ensure the server behaves as expected.

    In your project root, create a `.cursor/rules/pinecone.mdc` file and add the following:

    ```mdx [expandable] theme={null}
    ### Tool Usage for Code Generation

    - When generating code related to Pinecone, always use the `pinecone` MCP and the `search_docs` tool.

    - Perform at least two distinct searches per request using different, relevant questions to ensure comprehensive context is gathered before writing code.

    ### Error Handling

    - If an error occurs while executing Pinecone-related code, immediately invoke the `pinecone` MCP and the `search_docs` tool.

    - Search for guidance on the specific error encountered and incorporate any relevant findings into your resolution strategy.

    ### Syntax and Version Accuracy

    - Before writing any code, verify and use the correct syntax for the latest stable version of the Pinecone SDK.

    - Prefer official code snippets and examples from documentation over generated or assumed field values.

    - Do not fabricate field names, parameter values, or request formats.

    ### SDK Installation Best Practices

    - When providing installation instructions, always reference the current official package name.

    - For Pinecone, use `pip install pinecone` not deprecated packages like `pinecone-client`.
    ```
  </Step>

  <Step title="Test the server">
    Press `Command + i` to open the Agent chat. Test the Pinecone MCP server with prompts that required the server to generate Pinceone-compatible code and perform tasks in your Pinecone account.

    Generate code:

    > Write a Python script that creates a dense index with integrated embedding, upserts 20 sentences about dogs, waits 10 seconds, searches the index, and reranks the results.

    Perform tasks:

    > Create a dense index with integrated embedding, upsert 20 sentences about dogs, waits 10 seconds, search the index, and reranks the results.
  </Step>
</Steps>

## Configure Claude Desktop

<Steps>
  <Step title="Add the MCP server">
    Go to **Settings > Developer > Edit Config** and add the following configuration:

    ```json  theme={null}
    {
      "mcpServers": {
        "pinecone": {
          "command": "npx",
          "args": [
            "-y", "@pinecone-database/mcp"
          ],
          "env": {
            "PINECONE_API_KEY": "YOUR_API_KEY"
          }
        }
      }
    }
    ```

    Replace `YOUR_API_KEY` with your Pinecone API key.
  </Step>

  <Step title="Check the status">
    Restart Claude Desktop. On the new chat screen, you should see a hammer (MCP) icon appear with the new MCP tools available.
  </Step>

  <Step title="Test the server">
    Test the Pinecone MCP server with prompts that required the server to generate Pinceone-compatible code and perform tasks in your Pinecone account.

    Generate code:

    > Write a Python script that creates a dense index with integrated embedding, upserts 20 sentences about dogs, waits 10 seconds, searches the index, and reranks the results.

    Perform tasks:

    > Create a dense index with integrated embedding, upsert 20 sentences about dogs, waits 10 seconds, search the index, and reranks the results.
  </Step>
</Steps>

## Configure Claude Code

<Steps>
  <Step title="Add the MCP server">
    Run the following command to add the Pinecone MCP server to your Claude Code instance:

    ```bash  theme={null}
    claude mcp add-json pinecone-mcp \
      '{"type": "stdio",
        "command": "npx",
        "args": ["-y", "@pinecone-database/mcp"],
        "env": {"PINECONE_API_KEY": "YOUR_API_KEY"}}'
    ```

    Replace `YOUR_API_KEY` with your Pinecone API key.
  </Step>

  <Step title="Check the status">
    Restart Claude Code. Then, run the `/mcp` command to check the status of the Pinecone MCP. You should see the following:

    ```bash  theme={null}
      > /mcp 
        ⎿  MCP Server Status

          • pinecone-mcp: ✓ connected

    ```
  </Step>

  <Step title="Test the server">
    Test the Pinecone MCP server with prompts to Claude Code that require the server to generate Pinceone-compatible code and perform tasks in your Pinecone account.

    Generate code:

    > Write a Python script that creates a dense index with integrated embedding, upserts 20 sentences about dogs, waits 10 seconds, searches the index, and reranks the results.

    Perform tasks:

    > Create a dense index with integrated embedding, upsert 20 sentences about dogs, waits 10 seconds, search the index, and reranks the results.
  </Step>
</Steps>