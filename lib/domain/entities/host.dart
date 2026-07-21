import 'package:equatable/equatable.dart';

/// Group a host falls into when the user leaves the group field blank.
const kDefaultGroup = '기본';

/// Authentication method used to connect to a [Host].
enum AuthMethod { password, sshKey }

/// A saved SSH host. Contains only non-secret metadata; the actual secret
/// (password or private key) is stored separately in the secure vault and
/// referenced by [credentialId].
class Host extends Equatable {
  const Host({
    required this.id,
    required this.label,
    required this.hostname,
    required this.port,
    required this.username,
    required this.authMethod,
    this.groupName,
    this.credentialId,
  });

  final String id;
  final String label;
  final String hostname;
  final int port;
  final String username;
  final AuthMethod authMethod;

  /// Optional grouping folder shown in the host list.
  final String? groupName;

  /// Key into the secure vault where this host's secret is stored.
  /// Null until a credential has been attached.
  final String? credentialId;

  Host copyWith({
    String? id,
    String? label,
    String? hostname,
    int? port,
    String? username,
    AuthMethod? authMethod,
    String? groupName,
    String? credentialId,
  }) {
    return Host(
      id: id ?? this.id,
      label: label ?? this.label,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      authMethod: authMethod ?? this.authMethod,
      groupName: groupName ?? this.groupName,
      credentialId: credentialId ?? this.credentialId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        label,
        hostname,
        port,
        username,
        authMethod,
        groupName,
        credentialId,
      ];
}
