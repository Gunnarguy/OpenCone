# Architecture

> Learn how Pinecone's architecture enables fast, relevant vector search at any scale.

## Overview

Pinecone runs as a managed service on AWS, GCP, and Azure cloud platforms. When you send a request to Pinecone, it goes through an [API gateway](#api-gateway) that routes it to either a global [control plane](#control-plane) or a regional [data plane](#data-plane). All your vector data is stored in highly efficient, distributed [object storage](#object-storage).

<img className="block max-w-full dark:hidden" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview.svg?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=98d91bc4ea7c58f6b8d35fe679b68c0b" data-og-width="740" width="740" data-og-height="360" height="360" data-path="images/serverless-overview.svg" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview.svg?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=42998453798bb153dc3fa580414f9410 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview.svg?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=d807aaf9e8dfa5e7bdc6377507517155 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview.svg?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=aa2420a330195baad94c7c718f40eb73 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview.svg?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=024214355578dbdfcd939e0a0a77a946 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview.svg?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=4dc6a2bbfb7ee1df5cbc3f93a4190fea 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview.svg?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=1629f421c3ebbcca5ea344c751cdc8a7 2500w" />

<img className="hidden max-w-full dark:block" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview-dark.svg?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=49b931899a98acb5da51441f45593969" data-og-width="740" width="740" data-og-height="360" height="360" data-path="images/serverless-overview-dark.svg" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview-dark.svg?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=c1fbcd86c10d1a42a19369505d0edde5 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview-dark.svg?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=ef25b5617fddac002e73e7b47fe49101 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview-dark.svg?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=867f8807965bfb7910ac6e20bf88b4e4 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview-dark.svg?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=361c86e1fca74d10518658b0749d7307 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview-dark.svg?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=4a57619eeb614dd8e6126ab694cd966d 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-overview-dark.svg?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=ddb67f508a79e45b8128bac633ed62d9 2500w" />

### API gateway

Every request to Pinecone includes an [API key](/guides/projects/manage-api-keys) that's assigned to a specific [project](/guides/projects/understanding-projects). The API gateway first validates your API key to make sure you have permission to access the project. Once validated, it routes your request to either the global control plane (for managing projects and indexes) or a regional data plane (for reading and writing data), depending on what you're trying to do.

### Control plane

The global control plane manages your organizational resources like projects and indexes. It uses a dedicated database to keep track of all these objects. The control plane also handles billing, user management, and coordinates operations across different regions.

### Data plane

The data plane handles all requests to write and read records in [indexes](/guides/index-data/indexing-overview) within a specific [cloud region](/guides/index-data/create-an-index#cloud-regions). Each index is divided into one or more logical [namespaces](/guides/index-data/indexing-overview#namespaces), and all your read and write requests target a specific namespace.

Pinecone separates write and read operations into different paths, with each scaling independently based on demand. This separation ensures that your queries never slow down your writes, and your writes never slow down your queries.

### Object storage

For each namespace in a serverless index, Pinecone organizes records into immutable files called slabs. These slabs are [optimized for fast querying](#index-builder) and stored in distributed object storage that provides virtually unlimited scalability and high availability.

## Write path

<img className="block max-w-full dark:hidden" noZoom src="https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path.svg?fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=ecff622da831c3a66daa97bdf2697382" data-og-width="940" width="940" data-og-height="620" height="620" data-path="images/serverless-write-path.svg" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path.svg?w=280&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=9808682d3f6e0e495f22c5b61deff011 280w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path.svg?w=560&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=28edc7e9a311ef4e033f6deb7a0cbd75 560w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path.svg?w=840&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=bb437ade62614b058dd09395e8a32362 840w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path.svg?w=1100&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=3b0ee72f562e2f41c08ea3d2afdcc5ba 1100w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path.svg?w=1650&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=e9b1813aae24f88359114325b4ab2a79 1650w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path.svg?w=2500&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=4c725c7f6ca06a6bff68e6785fb1bb70 2500w" />

<img className="hidden max-w-full dark:block" noZoom src="https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path-dark.svg?fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=d456221c3a09d5ddc2decb7753cfebc3" data-og-width="940" width="940" data-og-height="620" height="620" data-path="images/serverless-write-path-dark.svg" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path-dark.svg?w=280&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=988867bbb19ca047d50efe6354b5cefb 280w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path-dark.svg?w=560&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=a85024b967a3f3327f28d00a61d15265 560w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path-dark.svg?w=840&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=d1aad53d8a276f75ab844b337b3271ba 840w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path-dark.svg?w=1100&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=62c9f8af12acb68707c5876f46be9547 1100w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path-dark.svg?w=1650&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=39e08abbbe141f2da52783872a7ebb25 1650w, https://mintcdn.com/pinecone/JWPNAjHjOsqAgQOo/images/serverless-write-path-dark.svg?w=2500&fit=max&auto=format&n=JWPNAjHjOsqAgQOo&q=85&s=69e381ad399e323ec6d9bebc57d78578 2500w" />

### Request log

When you send a write request (to add, update, or delete records), the [data plane](#data-plane) first logs the request details with a unique sequence number (LSN). This ensures all operations happen in the correct order and provides a way to track the state of the index.

Pinecone immediately returns a `200 OK` response, guaranteeing that your write is durable and won't be lost. The system then processes your write in the background.

### Index builder

The index builder stores your write data in an in-memory structure called a memtable. This includes your vector data, any metadata you've attached, and the sequence number. If you're updating or deleting a record, the system also tracks how to handle the old version during queries.

Periodically, the index builder moves data from the memtable to permanent storage. In [object storage](#object-storage), your data is organized into immutable files called slabs. These slabs are optimized for query performance. Smaller slabs use fast indexing techniques that provide good performance with minimal resource requirements. As slabs grow, the system merges them into larger slabs that use more sophisticated methods that provide better performance at scale. This adaptive process both optimizes query performance for each slab and amortizes the cost of more expensive indexing through the lifetime of the namespace.

<Note>
  All read operations check the memtable first, so you can immediately search data that you've just written, even before it's moved to permanent storage. For more details, see [Query executors](#query-executors).
</Note>

## Read path

<img className="block max-w-full dark:hidden" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path.svg?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=72b1e07346aed7b8d1ba57c3921671dc" data-og-width="780" width="780" data-og-height="620" height="620" data-path="images/serverless-read-path.svg" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path.svg?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=c79e043ee7f88f12f84c203004bc76f2 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path.svg?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=d8621e6936b3e164256f77ed60a26e96 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path.svg?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=b1fdeb25ef032032553a0ef1b39e47ee 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path.svg?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=8b53c093092386d6519fb38b4051caa5 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path.svg?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=74f3a707be64e5ad09cf059ebe85195a 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path.svg?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=cff6162f9c68c34998e3771f4303c6a6 2500w" />

<img className="hidden max-w-full dark:block" noZoom src="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path-dark.svg?fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=550f3a697b7158fe3d424c70df7c8242" data-og-width="780" width="780" data-og-height="620" height="620" data-path="images/serverless-read-path-dark.svg" data-optimize="true" data-opv="3" srcset="https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path-dark.svg?w=280&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=eaaa5125f10a76ba2d40b27ccfd3daf7 280w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path-dark.svg?w=560&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=9a3e9166c8c861e804f02e505984975b 560w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path-dark.svg?w=840&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=9c6ec5b4fe6e7b94ae312c45cd48f051 840w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path-dark.svg?w=1100&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=c1f67150c9832d7f8b9701485c912a24 1100w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path-dark.svg?w=1650&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=f019f8d47b3c908021c20d0cb0325a3f 1650w, https://mintcdn.com/pinecone/r0TaYXrfSrAYZYUj/images/serverless-read-path-dark.svg?w=2500&fit=max&auto=format&n=r0TaYXrfSrAYZYUj&q=85&s=1d475b0bbef6850adb84b6993acadc5e 2500w" />

### Query routers

When you send a search query, the [data plane](#data-plane) first validates your request and checks that it meets system limits like [rate and object limits](/reference/api/database-limits.mdx). The query router then identifies which slabs contain relevant data and routes your query to the appropriate executors. It also searches the memtable for any recent data that hasn't been moved to permanent storage yet.

### Query executors

Each query executor searches through its assigned slabs and returns the most relevant candidates to the query router. If your query includes metadata filters, the executors exclude records that don't match your criteria before finding the best matches.

Most of the time, the slabs are cached in memory or on local SSD, which provides very fast query performance. If a slab isn't cached (which happens when it's accessed for the first time or hasn't been used recently), the executor fetches it from object storage and caches it for future queries.

The query router then combines results from all executors, removes duplicates, merges them with results from the memtable, and returns the final set of best matches to you.
