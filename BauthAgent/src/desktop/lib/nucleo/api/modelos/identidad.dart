// ============================================================
// bauth_desktop · nucleo/api/modelos/identidad.dart
//
// Modelos de identidad: roles, plantillas, usuarios, entidades.
// Part of bauth_api.dart — comparte librería y helpers _es/_esN.
// ============================================================

part of '../bauth_api.dart';

/// Información de un rol activo (bauth.role.list).
class RolInfo {
  final String  id;
  final String  nombre;
  final String? tier;
  final String? status;
  final int     atomCount;

  RolInfo.fromJson(Map<String, dynamic> j)
      : id        = j['id'] ?? j['role_id'] ?? '?',
        nombre    = j['name'] ?? j['nombre'] ?? '?',
        tier      = j['tier'],
        status    = j['status'],
        atomCount = j['atom_count'] ?? 0;
}

/// Plantilla de rol (bauth.role.template.*).
class RolTemplate {
  final String              id;
  final String              nombre;
  final String              version;
  final String?             dominio;
  final Map<String, dynamic>? metadata;

  RolTemplate.fromJson(Map<String, dynamic> j)
      : id       = j['id']                        ?? '?',
        nombre   = j['name'] ?? j['nombre']       ?? '?',
        version  = j['version']                   ?? '?',
        dominio  = j['domain'] ?? j['dominio'],
        metadata = j['metadata'] as Map<String, dynamic>?;
}

/// Información de un usuario (bauth.user.*).
class UsuarioInfo {
  final String       uuid;
  final String       username;
  final String?      email;
  final String?      accountType;
  final String?      status;
  final List<String> roles;

  UsuarioInfo.fromJson(Map<String, dynamic> j)
      : uuid        = j['uuid']         ?? '?',
        username    = j['username']     ?? '?',
        email       = j['email'],
        accountType = j['account_type'],
        status      = j['status'],
        roles       = (j['roles'] as List<dynamic>?)
                          ?.map((e) => e.toString()).toList() ?? [];
}

/// Entidad del catálogo universal de identidad (idn_identity_entity).
/// Cualquier cosa es una entidad: persona, empresa, vehículo, servidor, sensor, puerta.
/// 5 niveles jerárquicos: tenant → bdomain → bsubdomain → pos → actor.
class EntidadInfo {
  final String          entidadId;
  final String?         parentId;
  final String          tenantId;
  final String          nivel;   // tenant | bdomain | bsubdomain | pos | actor
  final String          tipo;    // empresa, HUMAN, caja, vehiculo, servidor…
  final String          nombre;
  final String          slug;
  final bool?           isInternal;
  final int             sortOrder;
  final List<EntidadInfo> hijos;

  EntidadInfo.fromJson(Map<String, dynamic> j)
      : entidadId  = j['entity_id'] ?? j['id'] ?? '?',
        parentId   = j['parent_id'],
        tenantId   = j['tenant_id']  ?? '?',
        nivel      = j['level'] ?? j['nivel'] ?? '?',
        tipo       = j['entity_type'] ?? j['tipo'] ?? '?',
        nombre     = j['nombre'] ?? j['name'] ?? '?',
        slug       = j['slug']   ?? '?',
        isInternal = j['is_internal'] as bool?,
        sortOrder  = j['sort_order'] ?? 0,
        hijos      = (j['hijos'] as List<dynamic>? ?? [])
                         .map((e) => EntidadInfo.fromJson(e as Map<String, dynamic>))
                         .toList();
}
