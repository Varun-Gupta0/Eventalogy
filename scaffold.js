const fs = require('fs');
const path = require('path');

const collections = [
  {
    name: 'Events',
    collection: 'events',
    model: 'EventModel',
    idField: 'eventId',
    fields: [
      { name: 'eventId', type: 'String', required: true },
      { name: 'customerId', type: 'String', required: true },
      { name: 'eventTypeId', type: 'String', required: true },
      { name: 'title', type: 'String', required: true },
      { name: 'eventDate', type: 'Timestamp', required: true },
      { name: 'guestCount', type: 'int?', required: false },
      { name: 'budget', type: 'double?', required: false },
      { name: 'locationId', type: 'String?', required: false },
      { name: 'venueId', type: 'String?', required: false },
      { name: 'requirements', type: 'Map<String, dynamic>?', required: false },
      { name: 'status', type: 'String', required: true },
      { name: 'paymentStatus', type: 'String?', required: false },
      { name: 'createdAt', type: 'Timestamp', required: true },
      { name: 'updatedAt', type: 'Timestamp?', required: false },
    ]
  },
  {
    name: 'Enquiries',
    collection: 'enquiries',
    model: 'EnquiryModel',
    idField: 'enquiryId',
    fields: [
      { name: 'enquiryId', type: 'String', required: true },
      { name: 'eventId', type: 'String', required: true },
      { name: 'customerId', type: 'String', required: true },
      { name: 'vendorId', type: 'String', required: true },
      { name: 'serviceId', type: 'String', required: true },
      { name: 'message', type: 'String', required: true },
      { name: 'requirements', type: 'Map<String, dynamic>?', required: false },
      { name: 'requestedDate', type: 'Timestamp', required: true },
      { name: 'status', type: 'String', required: true },
      { name: 'createdAt', type: 'Timestamp', required: true },
      { name: 'updatedAt', type: 'Timestamp?', required: false },
    ]
  },
  {
    name: 'Bookings',
    collection: 'bookings',
    model: 'BookingModel',
    idField: 'bookingId',
    fields: [
      { name: 'bookingId', type: 'String', required: true },
      { name: 'eventId', type: 'String', required: true },
      { name: 'customerId', type: 'String', required: true },
      { name: 'vendorId', type: 'String', required: true },
      { name: 'serviceId', type: 'String', required: true },
      { name: 'venueId', type: 'String?', required: false },
      { name: 'packageId', type: 'String?', required: false },
      { name: 'amount', type: 'double', required: true },
      { name: 'status', type: 'String', required: true },
      { name: 'paymentStatus', type: 'String', required: true },
      { name: 'bookingDate', type: 'Timestamp', required: true },
      { name: 'createdAt', type: 'Timestamp', required: true },
      { name: 'updatedAt', type: 'Timestamp?', required: false },
    ]
  },
  {
    name: 'Allocations',
    collection: 'allocations',
    model: 'AllocationModel',
    idField: 'allocationId',
    fields: [
      { name: 'allocationId', type: 'String', required: true },
      { name: 'eventId', type: 'String', required: true },
      { name: 'vendorId', type: 'String?', required: false },
      { name: 'venueId', type: 'String?', required: false },
      { name: 'serviceId', type: 'String?', required: false },
      { name: 'assignedBy', type: 'String', required: true },
      { name: 'status', type: 'String', required: true },
      { name: 'startTime', type: 'Timestamp', required: true },
      { name: 'endTime', type: 'Timestamp', required: true },
      { name: 'createdAt', type: 'Timestamp', required: true },
    ]
  },
  {
    name: 'Payments',
    collection: 'payments',
    model: 'PaymentModel',
    idField: 'paymentId',
    fields: [
      { name: 'paymentId', type: 'String', required: true },
      { name: 'eventId', type: 'String', required: true },
      { name: 'bookingId', type: 'String', required: true },
      { name: 'customerId', type: 'String', required: true },
      { name: 'amount', type: 'double', required: true },
      { name: 'currency', type: 'String', required: true },
      { name: 'paymentMethod', type: 'String', required: true },
      { name: 'transactionId', type: 'String', required: true },
      { name: 'status', type: 'String', required: true },
      { name: 'paidAt', type: 'Timestamp?', required: false },
      { name: 'createdAt', type: 'Timestamp', required: true },
    ]
  },
  {
    name: 'Reviews',
    collection: 'reviews',
    model: 'ReviewModel',
    idField: 'reviewId',
    fields: [
      { name: 'reviewId', type: 'String', required: true },
      { name: 'eventId', type: 'String', required: true },
      { name: 'customerId', type: 'String', required: true },
      { name: 'vendorId', type: 'String', required: true },
      { name: 'venueId', type: 'String?', required: false },
      { name: 'rating', type: 'int', required: true },
      { name: 'comment', type: 'String', required: true },
      { name: 'createdAt', type: 'Timestamp', required: true },
    ]
  },
  {
    name: 'Notifications',
    collection: 'notifications',
    model: 'NotificationModel',
    idField: 'notificationId',
    fields: [
      { name: 'notificationId', type: 'String', required: true },
      { name: 'userId', type: 'String', required: true },
      { name: 'type', type: 'String', required: true },
      { name: 'title', type: 'String', required: true },
      { name: 'message', type: 'String', required: true },
      { name: 'eventId', type: 'String?', required: false },
      { name: 'read', type: 'bool', required: true },
      { name: 'createdAt', type: 'Timestamp', required: true },
    ]
  },
  {
    name: 'AiPlans',
    collection: 'ai_plans',
    model: 'AiPlanModel',
    idField: 'planId',
    fields: [
      { name: 'planId', type: 'String', required: true },
      { name: 'eventId', type: 'String', required: true },
      { name: 'userId', type: 'String', required: true },
      { name: 'eventRequirements', type: 'Map<String, dynamic>', required: true },
      { name: 'recommendations', type: 'List<dynamic>', required: true },
      { name: 'estimatedBudget', type: 'double', required: true },
      { name: 'status', type: 'String', required: true },
      { name: 'createdAt', type: 'Timestamp', required: true },
      { name: 'updatedAt', type: 'Timestamp?', required: false },
    ]
  },
  {
    name: 'AiRecommendations',
    collection: 'ai_recommendations',
    model: 'AiRecommendationModel',
    idField: 'recommendationId',
    fields: [
      { name: 'recommendationId', type: 'String', required: true },
      { name: 'eventId', type: 'String', required: true },
      { name: 'serviceId', type: 'String?', required: false },
      { name: 'vendorId', type: 'String?', required: false },
      { name: 'venueId', type: 'String?', required: false },
      { name: 'reason', type: 'String', required: true },
      { name: 'score', type: 'double', required: true },
      { name: 'status', type: 'String', required: true },
      { name: 'createdAt', type: 'Timestamp', required: true },
    ]
  },
  {
    name: 'AgentTasks',
    collection: 'agent_tasks',
    model: 'AgentTaskModel',
    idField: 'taskId',
    fields: [
      { name: 'taskId', type: 'String', required: true },
      { name: 'agentType', type: 'String', required: true },
      { name: 'eventId', type: 'String', required: true },
      { name: 'taskType', type: 'String', required: true },
      { name: 'input', type: 'Map<String, dynamic>', required: true },
      { name: 'output', type: 'Map<String, dynamic>?', required: false },
      { name: 'status', type: 'String', required: true },
      { name: 'requiresApproval', type: 'bool', required: true },
      { name: 'approvedBy', type: 'String?', required: false },
      { name: 'createdAt', type: 'Timestamp', required: true },
      { name: 'completedAt', type: 'Timestamp?', required: false },
    ]
  },
  {
    name: 'AgentLogs',
    collection: 'agent_logs',
    model: 'AgentLogModel',
    idField: 'logId',
    fields: [
      { name: 'logId', type: 'String', required: true },
      { name: 'agentType', type: 'String', required: true },
      { name: 'taskId', type: 'String', required: true },
      { name: 'action', type: 'String', required: true },
      { name: 'input', type: 'Map<String, dynamic>', required: true },
      { name: 'output', type: 'Map<String, dynamic>?', required: false },
      { name: 'result', type: 'String', required: true },
      { name: 'timestamp', type: 'Timestamp', required: true },
    ]
  },
  {
    name: 'AuditLogs',
    collection: 'audit_logs',
    model: 'AuditLogModel',
    idField: 'logId',
    fields: [
      { name: 'logId', type: 'String', required: true },
      { name: 'actorId', type: 'String', required: true },
      { name: 'actorRole', type: 'String', required: true },
      { name: 'action', type: 'String', required: true },
      { name: 'resourceType', type: 'String', required: true },
      { name: 'resourceId', type: 'String', required: true },
      { name: 'metadata', type: 'Map<String, dynamic>?', required: false },
      { name: 'timestamp', type: 'Timestamp', required: true },
    ]
  },
  {
    name: 'Settings',
    collection: 'settings',
    model: 'SettingModel',
    idField: 'settingId',
    fields: [
      { name: 'settingId', type: 'String', required: true },
      { name: 'value', type: 'Map<String, dynamic>', required: true },
      { name: 'updatedAt', type: 'Timestamp', required: true },
    ]
  }
];

function camelToSnake(str) {
  return str.replace(/[A-Z]/g, function(letter) { return '_' + letter.toLowerCase(); });
}

function getDefaultValue(type) {
  if (type.includes('?')) return 'null';
  if (type === 'String') return "''";
  if (type === 'int') return '0';
  if (type === 'double') return '0.0';
  if (type === 'bool') return 'false';
  if (type === 'Timestamp') return 'Timestamp.now()';
  if (type.includes('List')) return '[]';
  if (type.includes('Map')) return '{}';
  return 'null';
}

function generateModel(c) {
  const fileName = camelToSnake(c.name).replace(/^_/, '') + '_model.dart';
  const outPath = path.join('d:/Projects/Eventology/eventology_app/lib/models', fileName);
  
  const fields = c.fields.map(function(f) { return '  final ' + f.type + ' ' + f.name + ';'; }).join('\n');
  const constructorArgs = c.fields.map(function(f) { return '    ' + (f.required ? 'required ' : '') + 'this.' + f.name + ','; }).join('\n');
  
  const fromFirestore = c.fields.map(function(f) {
    let cast = "data['" + f.name + "'] as " + f.type.replace('?', '') + "?";
    if (f.type.includes('List')) {
      return "      " + f.name + ": List.from(data['" + f.name + "'] as List? ?? []),";
    }
    if (f.type.includes('Map')) {
      if (f.required) return "      " + f.name + ": Map<String, dynamic>.from(data['" + f.name + "'] as Map? ?? {}),";
      return "      " + f.name + ": data['" + f.name + "'] != null ? Map<String, dynamic>.from(data['" + f.name + "'] as Map) : null,";
    }
    if (f.type === 'double' || f.type === 'double?') {
      return "      " + f.name + ": (data['" + f.name + "'] as num?)?.toDouble()" + (f.required ? ' ?? 0.0' : '') + ",";
    }
    if (f.name === c.idField) {
      return "      " + f.name + ": data['" + f.name + "'] as String? ?? doc.id,";
    }
    return "      " + f.name + ": " + cast + (f.required ? " ?? " + getDefaultValue(f.type) : "") + ",";
  }).join('\n');

  const toFirestore = c.fields.map(function(f) {
    if (f.required) {
      return "      '" + f.name + "': " + f.name + ",";
    }
    return "      if (" + f.name + " != null) '" + f.name + "': " + f.name + ",";
  }).join('\n');

  const copyWithArgs = c.fields.map(function(f) { return "    " + f.type.replace('?', '') + "? " + f.name + ","; }).join('\n');
  const copyWithBody = c.fields.map(function(f) { return "      " + f.name + ": " + f.name + " ?? this." + f.name + ","; }).join('\n');

  const content = "import 'package:cloud_firestore/cloud_firestore.dart';\n\nclass " + c.model + " {\n" + fields + "\n\n  const " + c.model + "({\n" + constructorArgs + "\n  });\n\n  factory " + c.model + ".fromFirestore(DocumentSnapshot doc) {\n    final data = doc.data() as Map<String, dynamic>? ?? {};\n    return " + c.model + "(\n" + fromFirestore + "\n    );\n  }\n\n  Map<String, dynamic> toFirestore() {\n    return {\n" + toFirestore + "\n    };\n  }\n\n  " + c.model + " copyWith({\n" + copyWithArgs + "\n  }) {\n    return " + c.model + "(\n" + copyWithBody + "\n    );\n  }\n}\n";

  fs.writeFileSync(outPath, content);
}

function generateRepo(c) {
  const fileName = camelToSnake(c.name).replace(/^_/, '') + '_repository.dart';
  const outPath = path.join('d:/Projects/Eventology/eventology_app/lib/services/firestore', fileName);
  
  const content = "import 'package:cloud_firestore/cloud_firestore.dart';\nimport '../../core/firebase/firestore_config.dart';\nimport '../../core/database/collections.dart';\nimport '../../models/" + camelToSnake(c.name).replace(/^_/, '') + "_model.dart';\n\nclass " + c.name + "Repository {\n  static final FirebaseFirestore _db = FirestoreConfig.instance;\n\n  static CollectionReference<Map<String, dynamic>> get _col =>\n      _db.collection('" + c.collection + "');\n\n  static Future<String> create(" + c.model + " item) async {\n    final ref = " + (c.name === 'Settings' ? "_col.doc(item." + c.idField + ")" : "_col.doc()") + " ;\n    final data = item.toFirestore();\n    data['" + c.idField + "'] = ref.id;\n    if (data.containsKey('createdAt')) data['createdAt'] = FieldValue.serverTimestamp();\n    await ref.set(data);\n    return ref.id;\n  }\n\n  static Future<" + c.model + "?> get(String id) async {\n    final doc = await _col.doc(id).get();\n    if (!doc.exists) return null;\n    return " + c.model + ".fromFirestore(doc);\n  }\n\n  static Stream<List<" + c.model + ">> stream() {\n    return _col\n        .snapshots()\n        .map((s) => s.docs.map((d) => " + c.model + ".fromFirestore(d)).toList());\n  }\n\n  static Future<void> update(" + c.model + " item) async {\n    final updates = item.toFirestore();\n    updates.remove('createdAt');\n    if (updates.containsKey('updatedAt')) updates['updatedAt'] = FieldValue.serverTimestamp();\n    await _col.doc(item." + c.idField + ").update(updates);\n  }\n\n  static Future<void> delete(String id) async {\n    await _col.doc(id).delete();\n  }\n}\n";

  fs.writeFileSync(outPath, content);
}

function generateAdminTab(c) {
  const fileName = 'admin_' + camelToSnake(c.name).replace(/^_/, '') + '_tab.dart';
  const outPath = path.join('d:/Projects/Eventology/eventology_app/lib/features/admin', fileName);
  
  const content = "import 'package:flutter/material.dart';\nimport '../../core/theme/app_colors.dart';\nimport '../../models/" + camelToSnake(c.name).replace(/^_/, '') + "_model.dart';\nimport '../../services/firestore/" + camelToSnake(c.name).replace(/^_/, '') + "_repository.dart';\n\nclass Admin" + c.name + "Tab extends StatefulWidget {\n  const Admin" + c.name + "Tab({super.key});\n\n  @override\n  State<Admin" + c.name + "Tab> createState() => _Admin" + c.name + "TabState();\n}\n\nclass _Admin" + c.name + "TabState extends State<Admin" + c.name + "Tab> {\n  @override\n  Widget build(BuildContext context) {\n    return StreamBuilder<List<" + c.model + ">>(\n      stream: " + c.name + "Repository.stream(),\n      builder: (context, snapshot) {\n        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));\n        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());\n\n        final items = snapshot.data!;\n        if (items.isEmpty) return const Center(child: Text('No records found.'));\n\n        return ListView.builder(\n          padding: const EdgeInsets.all(16),\n          itemCount: items.length,\n          itemBuilder: (context, index) {\n            final item = items[index];\n            return Card(\n              color: AppColors.surfaceLighter,\n              child: ListTile(\n                title: Text(item." + c.idField + ", style: const TextStyle(fontWeight: FontWeight.bold)),\n                subtitle: const Text('ID displayed'),\n                trailing: IconButton(\n                  icon: const Icon(Icons.delete, color: Colors.redAccent),\n                  onPressed: () => " + c.name + "Repository.delete(item." + c.idField + "),\n                ),\n              ),\n            );\n          },\n        );\n      },\n    );\n  }\n}\n";

  fs.writeFileSync(outPath, content);
}

function generateScript(c) {
  const fileName = 'verify' + c.name + '.ts';
  const outPath = path.join('d:/Projects/Eventology/eventology_backend/src/scripts', fileName);
  
  const expectedFields = c.fields.map(function(f) { return "'" + f.name + "'"; }).join(', ');

  const content = "import { initializeApp, cert, getApp } from 'firebase-admin/app';\nimport { getFirestore } from 'firebase-admin/firestore';\nimport * as path from 'path';\n\nconst serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');\nconst serviceAccount = require(serviceAccountPath);\ninitializeApp({ credential: cert(serviceAccount) });\n\nasync function verify() {\n  let db;\n  try {\n     db = getFirestore(getApp(), 'user-data');\n  } catch(e) {\n     db = getFirestore();\n  }\n\n  const snap = await db.collection('" + c.collection + "').get();\n  let totalCount = 0;\n  \n  const invalidId: string[] = [];\n  const unexpectedFields: string[] = [];\n  \n  const expectedFields = new Set([" + expectedFields + "]);\n\n  console.log('--- " + c.name.toUpperCase() + " DOCUMENTS ---');\n  snap.forEach(doc => {\n    totalCount++;\n    const data = doc.data();\n\n    if (!data." + c.idField + " || data." + c.idField + " !== doc.id) invalidId.push(doc.id);\n\n    for (const key of Object.keys(data)) {\n      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);\n    }\n  });\n\n  console.log('--- VERIFICATION REPORT ---');\n  console.log(`Total " + c.collection + " documents: ${totalCount}`);\n  console.log(`Invalid/missing ID: ${invalidId.length > 0 ? invalidId.join(', ') : 'None'}`);\n  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None'}`);\n  \n  process.exit(0);\n}\n\nverify();\n";

  fs.writeFileSync(outPath, content);
}

for (const c of collections) {
  generateModel(c);
  generateRepo(c);
  generateAdminTab(c);
  generateScript(c);
}

console.log('Done generating files!');
