‫# راهنمای دیتابیس و جدول‌های Dify

این سند بر اساس سورس همین نسخه از پروژه تهیه شده است، نه صرفاً بر اساس نام جدول‌ها. منابع اصلی، مدل‌های SQLAlchemy در `api/models/`، تنظیمات Docker در `docker/.env.example` و `docker/docker-compose.yaml` هستند.

## تصویر کلی ذخیره‌سازی

Dify در نصب Docker پیش‌فرض چند سامانهٔ ذخیره‌سازی جدا دارد:

- **PostgreSQL اصلی (`dify`)**: داده‌های تراکنشی برنامه، حساب‌ها، Workspaceها، اپ‌ها، گفتگوها، Knowledge Baseها، Workflowها، Providerها و ابزارها. ۱۳۸ جدول تصاویر ارسالی متعلق به همین دیتابیس هستند.
- **PostgreSQL افزونه‌ها (`dify_plugin`)**: دیتابیس مستقل Plugin Daemon است. نام آن از `DB_PLUGIN_DATABASE` می‌آید و schema آن بخشی از مدل‌های `api/models/` نیست.
- **Vector Store**: به‌صورت پیش‌فرض Weaviate است و embedding/index مورد استفاده برای بازیابی معنایی را نگه می‌دارد. جدول `embeddings` در PostgreSQL دفتر ثبت و شناسهٔ embedding است؛ خود بردار بسته به Vector Store می‌تواند خارج از PostgreSQL باشد.
- **Redis**: cache، قفل، صف و stateهای موقتی را نگه می‌دارد و جای PostgreSQL را نمی‌گیرد.
- **File storage**: فایل‌های واقعی معمولاً روی volume یا object storage قرار دارند؛ جدول‌هایی مانند `upload_files` metadata و کلید محل ذخیره‌سازی را نگه می‌دارند.

## نکته دربارهٔ روابط

در مدل‌های Dify بسیاری از ستون‌های `tenant_id`، `app_id`، `workflow_id` و مشابه آن رابطهٔ منطقی دارند، ولی همیشه با `ForeignKey` فیزیکی ساخته نشده‌اند. برای نمونه `messages.conversation_id` یک Foreign Key واقعی به `conversations.id` دارد، اما تعداد زیادی از رابطه‌ها فقط با شناسه و index مدیریت می‌شوند. بنابراین نبودن خط ارتباط در pgAdmin به معنای نبودن رابطه در منطق برنامه نیست.

## حساب، Workspace و دسترسی

منبع: `api/models/account.py`، `api/models/onboarding.py` و `api/models/credential_permission.py`.

- `accounts` — کاربران مدیریتی/سازندهٔ Dify؛ شامل ایمیل، رمز هش‌شده، زبان، timezone، وضعیت و زمان ورود است.
- `tenants` — Workspace یا فضای کاری چندمستاجری؛ plan، status، تنظیم سفارشی و کلید عمومی رمزنگاری را نگه می‌دارد.
- `tenant_account_joins` — عضویت حساب در Workspace، نقش عضو و اینکه Workspace جاری حساب کدام است.
- `account_integrates` — اتصال حساب به identity provider خارجی؛ provider، شناسهٔ خارجی و token رمز‌شده را نگه می‌دارد.
- `invitation_codes` — کدهای دعوت، batch و وضعیت مصرف آن‌ها.
- `account_plugin_permissions` — سیاست نصب و اشکال‌زدایی افزونه برای هر tenant؛ نام کلاس مدل `TenantPluginPermission` است.
- `tenant_plugin_auto_upgrade_strategies` — برنامه و سیاست ارتقای خودکار افزونه‌ها به تفکیک tenant و category.
- `account_step_by_step_tour_states` — وضعیت onboarding مرحله‌ای هر حساب، Workspace نخست و ردکردن tour.
- `credential_permissions` — مجوز اشتراک یک credential مشخص با حساب‌ها در یک tenant، بر اساس نوع credential.
- `tenant_credit_pools` — استخر اعتبار tenant و وضعیت مصرف/اعتبار سرویس‌های وابسته.

## اپ‌ها، انتشار و تنظیمات عمومی

منبع: `api/models/model.py`، `api/models/api_based_extension.py` و `api/models/snippet.py`.

- `dify_setups` — اطلاعات نصب Dify شامل نسخه، instance ID، زمان setup، heartbeat و گزارش نصب.
- `apps` — موجودیت مرکزی اپ؛ tenant، نام، mode، icon، توضیح، وضعیت و تنظیمات سطح اپ را نگه می‌دارد.
- `app_stars` — ستاره‌دارکردن یک اپ توسط یک account در tenant؛ روی ترکیب tenant/account/app یکتا است.
- `app_model_configs` — پیکربندی مدل یک اپ، شامل provider، model ID و configهای JSON.
- `recommended_apps` — اپ‌های پیشنهادی/فهرست‌شده، زبان، ترتیب نمایش و metadata انتشار.
- `installed_apps` — نصب یک اپ متعلق به tenant دیگر در Workspace مقصد و موقعیت نمایش آن.
- `trial_apps` — اپ‌های آزمایشی قابل استفاده توسط tenant؛ در سورس برای هر `app_id` یکتا است.
- `account_trial_app_records` — ثبت استفادهٔ یک حساب از trial app برای کنترل تجربهٔ آزمایشی.
- `exporle_banners` — bannerهای بخش Explore. املای `exporle` عین نام تاریخی جدول در سورس است.
- `oauth_provider_apps` — مشخصات OAuth applicationهای provider، مانند client ID و secret رمز‌شده.
- `sites` — تنظیمات سایت/WebApp منتشرشده برای اپ، مانند title، icon، theme و وضعیت انتشار.
- `api_tokens` — tokenهای API برای دسترسی به اپ یا tenant؛ token ذخیره‌شده و محدودهٔ مالکیت را نگه می‌دارد.
- `api_requests` — ثبت درخواست‌های API و اطلاعات request/response مورد نیاز برای مشاهده یا حسابرسی.
- `app_mcp_servers` — تنظیم انتشار یک اپ به‌صورت MCP server و وضعیت/شناسهٔ server آن.
- `api_based_extensions` — extension سفارشی tenant با endpoint و API key برای فراخوانی سرویس خارجی.
- `customized_snippets` — snippetهای قابل استفادهٔ مجدد، به‌خصوص قطعه‌های workflow/node و نسخهٔ draft/published آن‌ها.
- `trace_app_config` — تنظیم اتصال tracing/observability هر اپ به provider مربوطه.
- `tags` — تعریف tag در سطح tenant برای دسته‌بندی resourceهایی مانند app یا dataset.
- `tag_bindings` — جدول واسط اتصال tag به target مشخص، با نوع target و شناسهٔ آن.

## نسخهٔ schema و migration

منبع: migrationهای Alembic در `api/migrations/`.

- `alembic_version` — جدول مدیریتی Alembic که revision فعلی schema را نگه می‌دارد. این جدول مدل business در `api/models/` ندارد و نباید دستی ویرایش شود.

## گفتگو، پیام و تجربهٔ کاربر نهایی

منبع: `api/models/model.py` و `api/models/web.py`.

- `end_users` — کاربران نهایی اپ‌های منتشرشده؛ session شناسهٔ خارجی و tenant/app مالک را نگه می‌دارد.
- `conversations` — session مکالمه برای یک app و end user، همراه نام، وضعیت، ورودی‌ها، خلاصه و model config مؤثر.
- `messages` — پیام‌های یک conversation؛ query، answer، tokenها، هزینه، latency، status و metadata اجرای مدل را نگه می‌دارد.
- `message_chains` — زنجیره/شاخه‌بندی پیام‌ها برای نگهداری ارتباط نسخه‌ها یا مسیرهای یک مکالمه.
- `message_agent_thoughts` — گام‌های reasoning و tool invocation عامل در جریان تولید یک پیام.
- `message_feedbacks` — امتیاز یا بازخورد مثبت/منفی کاربر روی پیام، همراه متن تکمیلی.
- `message_files` — اتصال فایل‌های ورودی/خروجی به message و conversation.
- `message_annotations` — پاسخ‌های annotationشده برای پاسخ کنترل‌شده یا اصلاح پاسخ مدل.
- `app_annotation_settings` — تنظیم فعال‌بودن annotation reply و پارامترهای جست‌وجوی آن برای اپ.
- `app_annotation_hit_histories` — ثبت اینکه کدام annotation برای یک query/message بازیابی و استفاده شده است.
- `saved_messages` — bookmarkکردن یک message توسط account یا end user.
- `pinned_conversations` — سنجاق‌کردن conversation برای کاربر سازندهٔ آن.
- `upload_files` — metadata فایل آپلودی شامل نام، اندازه، MIME type، storage key، hash و مالک.
- `operation_logs` — audit log عملیات مدیریتی، actor، action، target و payload مرتبط.

## Knowledge Base، سند و RAG

منبع: `api/models/dataset.py`.

- `datasets` — Knowledge Base اصلی؛ tenant، نام، indexing technique، provider embedding، permission و وضعیت را نگه می‌دارد.
- `dataset_permissions` — دسترسی حساب‌ها به dataset در حالت permission محدود.
- `app_dataset_joins` — اتصال app به datasetهایی که برای retrieval استفاده می‌کند.
- `documents` — سند واردشده به dataset؛ منبع، وضعیت indexing، شمارندهٔ token/segment و خطاها را ثبت می‌کند.
- `document_segments` — chunkهای قابل بازیابی سند، همراه content، position، token count، index node ID و وضعیت.
- `child_chunks` — زیرchunkهای segment برای ساختار parent-child retrieval.
- `document_segment_summaries` — خلاصهٔ تولیدشده برای segment و metadata مربوط به summary.
- `segment_attachment_bindings` — اتصال فایل‌های ضمیمه به segmentهای سند.
- `dataset_process_rules` — ruleهای preprocess و segmentation مانند mode، separator و حداکثر طول chunk.
- `dataset_queries` — history جست‌وجوهای dataset، query، نتیجه/منبع و اطلاعات retrieval.
- `dataset_retriever_resources` — segmentهای بازیابی‌شده برای یک message، همراه score، position و محتوای منبع.
- `dataset_keyword_tables` — keyword/index کمکی مربوط به dataset برای روش‌های بازیابی غیرصرفاًبرداری.
- `embeddings` — نگاشت hash/content به شناسهٔ embedding و model؛ الزاماً محل نگهداری خود بردار نیست.
- `dataset_collection_bindings` — نگاشت dataset به collection خارجی Vector Store و provider آن.
- `tidb_auth_bindings` — credential و اتصال اختصاصی TiDB برای tenant/dataset.
- `whitelists` — فهرست سفید ایمیل/شناسه برای قابلیت‌ها یا دسترسی‌های dataset.
- `external_knowledge_apis` — endpoint و credential APIهای Knowledge خارجی.
- `external_knowledge_bindings` — اتصال dataset به Knowledge Base خارجی و API تعریف‌شده.
- `dataset_auto_disable_logs` — ثبت غیرفعال‌سازی خودکار dataset و علت/زمان آن.
- `rate_limit_logs` — رخدادهای rate limit در عملیات dataset/indexing.
- `dataset_metadatas` — تعریف فیلد metadata قابل استفاده در یک dataset.
- `dataset_metadata_bindings` — مقدار metadata یک document برای یک metadata definition.
- `pipeline_built_in_templates` — templateهای داخلی pipeline پردازش اسناد.
- `pipeline_customized_templates` — templateهای pipeline ساخته‌شده توسط tenant.
- `pipelines` — تعریف pipeline ingestion/indexing، graph/config و نسخهٔ منتشرشدهٔ آن.
- `document_pipeline_execution_logs` — log اجرای pipeline روی document، وضعیت، ورودی/خروجی و خطا.
- `pipeline_recommended_plugins` — افزونه‌های پیشنهادی یا لازم برای یک pipeline/template.

## Provider، مدل و credential

منبع: `api/models/provider.py`.

- `providers` — تنظیم provider مدل در سطح tenant، نوع credential و وضعیت فعال‌بودن.
- `provider_models` — مدل‌های سفارشی/اضافه‌شدهٔ provider و نوع مدل آن‌ها.
- `provider_credentials` — credentialهای نام‌گذاری‌شده در سطح provider و tenant؛ دادهٔ حساس به‌شکل رمز‌شده نگهداری می‌شود.
- `provider_model_credentials` — credential اختصاصی یک model در provider.
- `provider_model_settings` — تنظیم enable/load balancing و خصوصیات مدل برای tenant.
- `tenant_default_models` — مدل پیش‌فرض tenant برای هر model type و سناریو.
- `tenant_preferred_model_providers` — provider ترجیحی tenant برای یک نوع مدل.
- `provider_orders` — ترتیب نمایش/اولویت providerها در tenant.
- `load_balancing_model_configs` — endpoint/credentialهای متعدد یک مدل برای load balancing و وضعیت هر config.
- `credential_permissions` — ACL اشتراک credential؛ جزئیات آن در بخش حساب و دسترسی آمده است.

## ابزارها، MCP و اجرای Tool

منبع: `api/models/tools.py`.

- `tool_builtin_providers` — credential و تنظیمات providerهای ابزار داخلی برای tenant.
- `tool_api_providers` — provider ابزار مبتنی بر OpenAPI/API و schema/credential آن.
- `tool_workflow_providers` — تبدیل workflowهای Dify به provider/tool قابل فراخوانی.
- `tool_mcp_providers` — MCP serverهای متصل‌شده به tenant، transport، URL، credential و وضعیت آن‌ها.
- `tool_oauth_system_clients` — OAuth client سراسری ابزار برای provider/plugin.
- `tool_oauth_tenant_clients` — OAuth client اختصاصی tenant برای ابزار.
- `tool_label_bindings` — label/categoryهای متصل به provider ابزار برای جست‌وجو و نمایش.
- `tool_model_invokes` — ثبت فراخوانی model از مسیر tool، token usage، هزینه و جزئیات اجرا.
- `tool_conversation_variables` — variableهای تولیدشده یا مصرف‌شده توسط tool در یک conversation.
- `tool_files` — فایل‌هایی که به‌عنوان ورودی/خروجی اجرای tool استفاده شده‌اند.
- `tool_published_apps` — اپ‌های منتشرشده به‌عنوان tool؛ دارای Foreign Key واقعی به `apps.id` است.

## Workflow، اجرا و نسخه‌بندی

منبع: `api/models/workflow.py`، `api/models/comment.py` و `api/models/execution_extra_content.py`.

- `workflows` — graph و feature/config workflow برای یک app، با نوع draft/published، version و environment variables.
- `workflow_version_counters` — شمارندهٔ اتمیک نسخه‌های workflow برای جلوگیری از شمارهٔ تکراری.
- `workflow_runs` — یک اجرای کامل workflow؛ status، inputs، outputs، error، token، زمان و actor را ثبت می‌کند.
- `workflow_node_executions` — اجرای هر node در یک run؛ ورودی، خروجی، status، error، token، زمان و metadata.
- `workflow_node_execution_offload` — payloadهای بزرگ node execution که برای سبک نگه‌داشتن رکورد اصلی offload شده‌اند.
- `execution_extra_contents` — محتوای جانبی polymorphic اجرای workflow، با discriminator نوع و ارتباط منطقی با run/node execution.
- `workflow_app_logs` — log سطح اپ برای اجرای workflow از سمت end user یا API.
- `workflow_archive_logs` — وضعیت و نتیجهٔ archiveکردن داده‌های قدیمی workflow.
- `workflow_run_archive_bundles` — bundle/بستهٔ آرشیوی runها و محل/metadata ذخیره‌سازی آن.
- `workflow_conversation_variables` — متغیرهای پایدار conversation در workflowهای مکالمه‌ای.
- `workflow_draft_variables` — variableهای تعریف‌شده برای draft workflow و مقدار/type آن‌ها.
- `workflow_draft_variable_files` — فایل‌های متصل به draft variableها.
- `workflow_pauses` — وضعیت pause یک workflow run، token/زمان انقضا و اطلاعات resume.
- `workflow_pause_reasons` — علت‌های انتظار هر pause، مانند node یا رویداد منتظرمانده.
- `workflow_comments` — commentهای بوم workflow با مختصات، محتوا و سازنده.
- `workflow_comment_replies` — پاسخ‌های comment؛ Foreign Key واقعی و حذف آبشاری به comment دارد.
- `workflow_comment_mentions` — mention حساب در comment یا reply؛ به comment/reply متصل است.

## Trigger و زمان‌بندی Workflow

منبع: `api/models/trigger.py`.

- `app_triggers` — triggerهای تعریف‌شده در سطح اپ، provider، نوع trigger و subscription مربوطه.
- `trigger_subscriptions` — subscription فعال یک trigger خارجی، endpoint/config و وضعیت آن.
- `trigger_oauth_system_clients` — OAuth client سراسری برای trigger provider.
- `trigger_oauth_tenant_clients` — OAuth client اختصاصی tenant برای trigger provider.
- `workflow_trigger_logs` — log دریافت و پردازش trigger و نتیجهٔ شروع workflow.
- `workflow_webhook_triggers` — webhook triggerهای workflow، endpoint/secret و وضعیت انتشار.
- `workflow_plugin_triggers` — triggerهای ارائه‌شده توسط plugin و تنظیمات subscription آن‌ها.
- `workflow_schedule_plans` — برنامهٔ اجرای زمان‌بندی‌شده، cron/timezone و `next_run_at` برای app/node.

## Agent و Workspace عامل‌ها

منبع: `api/models/agent.py`.

- `agents` — هویت پایدار Agent و lineage آن؛ به tenant، app/workflow و snapshot فعال متصل می‌شود.
- `agent_home_snapshots` — snapshot منبع/خانهٔ Agent و چرخهٔ active/retired آن.
- `agent_debug_conversations` — conversation اختصاصی debug هر account و draft یک Agent.
- `agent_config_drafts` — config در حال ویرایش Agent، مالک draft و snapshot پایه.
- `agent_config_snapshots` — نسخهٔ immutable از Soul/config عامل، شمارهٔ version، summary و home snapshot.
- `agent_config_revisions` — تاریخچهٔ جابه‌جایی از snapshot قبلی به snapshot جاری با revision ترتیبی.
- `workflow_agent_node_bindings` — اتصال node و version مشخص workflow به Agent و snapshot config آن.
- `agent_workspaces` — فضای کاری mutable متعلق به یک scope محصول، مستقل از هویت Agent.
- `agent_workspace_bindings` — materializeکردن یک Agent در Workspace همراه نسخهٔ config و home snapshot مبنا.

## Human Input در Workflow

منبع: `api/models/human_input.py`.

- `human_input_forms` — فرم انتظار برای ورودی انسانی در workflow، run/node مالک، schema، status و expiration.
- `human_input_form_deliveries` — روش ارسال فرم مانند channel/provider و وضعیت delivery.
- `human_input_form_recipients` — گیرندگان هر delivery و وضعیت دسترسی/پاسخ آن‌ها.
- `human_input_form_upload_tokens` — token محدود برای آپلود فایل به یک فرم و recipient مشخص.
- `human_input_form_upload_files` — اتصال فایل آپلودشده به فرم و upload token مربوطه.

## Data Source و OAuth

منبع: `api/models/source.py` و `api/models/oauth.py`.

- `data_source_oauth_bindings` — اتصال OAuth قدیمی/عمومی data source در سطح tenant، access token و source info.
- `data_source_api_key_auth_bindings` — اتصال data source با API key/credential و provider/category.
- `datasource_oauth_params` — OAuth client params سراسری یک datasource plugin/provider.
- `datasource_oauth_tenant_params` — OAuth client params و enablement اختصاصی tenant.
- `datasource_providers` — instance نام‌گذاری‌شدهٔ datasource provider با credential رمز‌شده و auth type.
- `oauth_access_tokens` — access tokenهای صادرشده برای کلاینت/دستگاه، با prefix، expiry و subject؛ token خام به‌صورت امن مدیریت می‌شود.

## Celery و کارهای پس‌زمینه

منبع: `api/models/task.py`.

- `celery_taskmeta` — نتیجه، status، traceback و زمان پایان یک task در Celery result backend.
- `celery_tasksetmeta` — نتیجهٔ مجموعه/group از taskهای Celery.

## مسیرهای اصلی داده

### مسیر مکالمه

`tenants` ← `apps` ← `conversations` ← `messages` ← `message_agent_thoughts` / `message_files` / `message_feedbacks`

اگر RAG فعال باشد، `messages` از طریق `dataset_retriever_resources` به `document_segments` و سپس `documents` و `datasets` قابل ردیابی است.

### مسیر Knowledge Base

`tenants` ← `datasets` ← `documents` ← `document_segments` ← `child_chunks`

تنظیم پردازش در `dataset_process_rules`، metadata در `dataset_metadatas` و `dataset_metadata_bindings`، و نگاشت Vector Store در `dataset_collection_bindings` قرار دارد.

### مسیر Workflow

`apps` ← `workflows` ← `workflow_runs` ← `workflow_node_executions`

log سطح اپ در `workflow_app_logs`، متغیرهای conversation در `workflow_conversation_variables` و وضعیت توقف/ادامه در `workflow_pauses` و `workflow_pause_reasons` نگهداری می‌شود.

## ملاحظات مشاهده و تغییر مستقیم داده

- مشاهدهٔ داده با pgAdmin امن است، اما تغییر مستقیم رکوردها می‌تواند invariantهای سطح برنامه، cacheهای Redis یا indexهای Vector Store را ناسازگار کند.
- حذف `datasets`، `documents` یا `document_segments` فقط از PostgreSQL ممکن است دادهٔ orphan در Vector Store باقی بگذارد.
- حذف فایل از `upload_files` الزاماً فایل واقعی را از volume/object storage حذف نمی‌کند و برعکس.
- credentialها و tokenها ممکن است رمز‌شده یا hashشده باشند؛ مقدار دیتابیس لزوماً قابل استفادهٔ مستقیم نیست.
- برای backup سازگار، PostgreSQL، storage فایل و Vector Store باید با هم در نظر گرفته شوند.

## منابع سورس

- حساب و tenant: `api/models/account.py`
- اپ، گفتگو و پیام: `api/models/model.py`
- Knowledge/RAG: `api/models/dataset.py`
- Workflow: `api/models/workflow.py`
- Agent: `api/models/agent.py`
- Tool/MCP: `api/models/tools.py`
- Provider/model credential: `api/models/provider.py`
- Trigger: `api/models/trigger.py`
- Human input: `api/models/human_input.py`
- OAuth و data source: `api/models/oauth.py` و `api/models/source.py`
- تنظیم storageها: `docker/.env.example` و `docker/docker-compose.yaml`
