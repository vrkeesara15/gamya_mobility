/// Lightweight JSON-backed models. Each keeps the raw map so screens can read
/// extra fields without churn while the API evolves.
library;

typedef Json = Map<String, dynamic>;

num? _n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse(v.toString()));
int _i(dynamic v, [int d = 0]) => _n(v)?.toInt() ?? d;
String? _s(dynamic v) => v?.toString();
Json _j(dynamic v) => v is Json ? v : const {};
List<Json> _l(dynamic v) => v is List ? v.cast<Json>() : const [];

class Paged<T> {
  Paged({required this.items, required this.total, required this.page, required this.pageSize, required this.totalPages, this.extra = const {}});
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final Json extra;

  static Paged<T> fromJson<T>(Json j, T Function(Json) parse) => Paged(items: _l(j['items']).map(parse).toList(), total: _i(j['total']), page: _i(j['page'], 1), pageSize: _i(j['pageSize'], 10), totalPages: _i(j['totalPages'], 1), extra: j);
  static Paged<T> empty<T>() => Paged(items: [], total: 0, page: 1, pageSize: 10, totalPages: 1);

  int get from => total == 0 ? 0 : (page - 1) * pageSize + 1;
  int get to => total == 0 ? 0 : (from + items.length - 1);
}

class AuthUser {
  AuthUser(this.raw);
  final Json raw;
  factory AuthUser.fromJson(Json j) => AuthUser(j);
  Json toJson() => raw;

  String get id => _s(raw['id']) ?? '';
  String get role => _s(raw['role']) ?? '';
  String get fullName => _s(raw['fullName']) ?? '';
  String? get email => _s(raw['email']);
  String? get mobile => _s(raw['mobile']);
  String? get avatarUrl => _s(raw['avatarUrl']);
  String get status => _s(raw['status']) ?? 'PENDING';
  bool get isAdmin => role == 'ADMIN';
  bool get isDriver => role == 'DRIVER';
  bool get isSupervisor => role == 'SUPERVISOR';
  String? get adminRole => _s(_j(raw['admin'])['adminRole']);
  String get adminRoleLabel => adminRole == 'SUPER_ADMIN' ? 'Super Admin' : adminRole == 'OPS' ? 'Operations' : 'Admin';
  Json get supervisor => _j(raw['supervisor']);
  Json get driver => _j(raw['driver']);
  bool get faceVerified => (supervisor['faceVerified'] ?? driver['faceVerified']) == true;
  String? get code => _s(supervisor['code'] ?? driver['code']);
  String? get companyName => _s(supervisor['companyName']);
}

class PlatformInfo {
  PlatformInfo(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get name => _s(raw['name']) ?? 'Other';
  String get code => _s(raw['code']) ?? 'OTHER';
  String? get color => _s(raw['color']);
  String? get deepLinkScheme => _s(raw['deepLinkScheme']);
  String? get websiteUrl => _s(raw['websiteUrl']);
  bool get active => raw['active'] != false;
  int get trips => _i(raw['trips']);
  int get drivers => _i(raw['drivers']);
  int get vehicles => _i(raw['vehicles']);
  int get bookings => _i(raw['bookings']);
  int get adhocRequests => _i(raw['adhocRequests']);
}

class Supervisor {
  Supervisor(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get code => _s(raw['code']) ?? '';
  String get fullName => _s(raw['fullName']) ?? '';
  String? get email => _s(raw['email']);
  String? get mobile => _s(raw['mobile']);
  String? get avatarUrl => _s(raw['avatarUrl']);
  String get status => _s(raw['status']) ?? '';
  String? get employeeId => _s(raw['employeeId']);
  String get companyName => _s(raw['companyName']) ?? '';
  String? get clientId => _s(raw['clientId']);
  String? get designation => _s(raw['designation']);
  String get assignedLocations => _s(raw['assignedLocations']) ?? 'All Locations';
  List<Json> get locations => _l(raw['locations']);
  int get totalRequests => _i(raw['totalRequests']);
  int get totalBookings => _i(raw['totalBookings']);
  dynamic get dateOfJoining => raw['dateOfJoining'];
  dynamic get lastLoginAt => raw['lastLoginAt'];
  bool get faceVerified => raw['faceVerified'] == true;
  List<Json> get activities => _l(raw['activities']);
  List<Json> get recentRequests => _l(raw['recentRequests']);
}

class Driver {
  Driver(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get code => _s(raw['code']) ?? '';
  String get fullName => _s(raw['fullName']) ?? '';
  String? get email => _s(raw['email']);
  String? get mobile => _s(raw['mobile']);
  String? get avatarUrl => _s(raw['avatarUrl']);
  String get status => _s(raw['status']) ?? '';
  dynamic get dateOfBirth => raw['dateOfBirth'];
  String? get address => _s(raw['address']);
  dynamic get joiningDate => raw['joiningDate'];
  dynamic get lastActiveAt => raw['lastActiveAt'];
  bool get faceVerified => raw['faceVerified'] == true;
  num? get faceMatchScore => _n(raw['faceMatchScore']);
  String? get selfieUrl => _s(raw['selfieUrl']);
  String? get idPhotoUrl => _s(raw['idPhotoUrl']);
  String get platformNames => _s(raw['platformNames']) ?? 'Other';
  List<PlatformInfo> get platforms => _l(raw['platforms']).map(PlatformInfo.new).toList();
  Json? get vehicle => raw['vehicle'] is Json ? raw['vehicle'] as Json : null;
  List<Json> get vehicles => _l(raw['vehicles']);
  List<Json> get documents => _l(raw['documents']);
  Json get docs => _j(raw['docs']);
  String get docsLabel => _s(docs['label']) ?? '0/7';
  int get docsVerified => _i(docs['verified']);
  int get docsRequired => _i(docs['required'], 7);
  int get totalTrips => _i(raw['totalTrips']);
  num? get rating => _n(raw['rating']);
  Json get performance => _j(raw['performance']);
  List<Json> get trips => _l(raw['trips']);
  List<Json> get earnings => _l(raw['earnings']);
  List<Json> get activities => _l(raw['activities']);
  String? get blacklistReason => _s(raw['blacklistReason']);
}

class Vehicle {
  Vehicle(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get number => _s(raw['number']) ?? '';
  String get make => _s(raw['make']) ?? '';
  String get model => _s(raw['model']) ?? '';
  String get makeModel => _s(raw['makeModel']) ?? '$make $model';
  int get year => _i(raw['year']);
  String get type => _s(raw['type']) ?? '';
  String? get color => _s(raw['color']);
  String? get fuelType => _s(raw['fuelType']);
  String? get seatingCapacity => _s(raw['seatingCapacity']);
  String get status => _s(raw['status']) ?? '';
  String? get photoUrl => _s(raw['photoUrl']);
  List<Json> get photos => _l(raw['photos']);
  Json? get driver => raw['driver'] is Json ? raw['driver'] as Json : null;
  Json? get supervisor => raw['supervisor'] is Json ? raw['supervisor'] as Json : null;
  PlatformInfo? get platform => raw['platform'] is Json ? PlatformInfo(raw['platform'] as Json) : null;
  Json get compliance => _j(raw['compliance']);
  String get complianceLabel => _s(compliance['label']) ?? '0/7';
  String get complianceLevel => _s(compliance['level']) ?? 'UNDER_VERIFICATION';
  int get complianceVerified => _i(compliance['verified']);
  List<Json> get documents => _l(raw['documents']);
  dynamic get registrationDate => raw['registrationDate'];
  dynamic get permitValidTill => raw['permitValidTill'];
  dynamic get insuranceValidTill => raw['insuranceValidTill'];
  dynamic get pucValidTill => raw['pucValidTill'];
  dynamic get fitnessValidTill => raw['fitnessValidTill'];
  String? get currentLocation => _s(raw['currentLocation']);
  int get totalTrips => _i(raw['totalTrips']);
  List<Json> get trips => _l(raw['trips']);
  List<Json> get activities => _l(raw['activities']);
}

class Approval {
  Approval(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get type => _s(raw['type']) ?? '';
  String get typeLabel => _s(raw['typeLabel']) ?? type;
  String get status => _s(raw['status']) ?? '';
  String? get details => _s(raw['details']);
  dynamic get submittedAt => raw['submittedAt'];
  dynamic get reviewedAt => raw['reviewedAt'];
  String? get remarks => _s(raw['remarks']);
  int get ageDays => _i(raw['ageDays']);
  String? get subjectName => _s(raw['subjectName']);
  String? get subjectMobile => _s(raw['subjectMobile']);
  String? get subjectPhoto => _s(raw['subjectPhoto']);
  String? get vehicleNumber => _s(raw['vehicleNumber']);
  String? get vehicleLabel => _s(raw['vehicleLabel']);
  Json? get driver => raw['driver'] is Json ? raw['driver'] as Json : null;
  Json? get supervisor => raw['supervisor'] is Json ? raw['supervisor'] as Json : null;
  Json? get vehicle => raw['vehicle'] is Json ? raw['vehicle'] as Json : null;
  Json? get document => raw['document'] is Json ? raw['document'] as Json : null;
  List<Json> get activities => _l(raw['activities']);
  bool get isVehicle => type == 'VEHICLE_REGISTRATION';
}

class AdhocRequest {
  AdhocRequest(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get code => _s(raw['code']) ?? '';
  String get status => _s(raw['status']) ?? '';
  String? get clientName => _s(raw['clientName']);
  Json? get supervisor => raw['supervisor'] is Json ? raw['supervisor'] as Json : null;
  String? get contactName => _s(raw['contactName']);
  String? get contactMobile => _s(raw['contactMobile']);
  String get fromLocation => _s(raw['fromLocation']) ?? '';
  String get toLocation => _s(raw['toLocation']) ?? '';
  dynamic get scheduledAt => raw['scheduledAt'];
  String? get loginTime => _s(raw['loginTime']);
  String? get reportingTime => _s(raw['reportingTime']);
  int get passengers => _i(raw['passengers'], 1);
  String get vehicleType => _s(raw['vehicleType']) ?? '';
  int? get modelYearMin => _n(raw['modelYearMin'])?.toInt();
  int get numberOfVehicles => _i(raw['numberOfVehicles'], 1);
  String get bookingType => _s(raw['bookingType']) ?? 'INSTANT';
  PlatformInfo? get platform => raw['platform'] is Json ? PlatformInfo(raw['platform'] as Json) : null;
  String get platformName => platform?.name ?? _s(raw['otherPlatformName']) ?? 'Other';
  String? get specialInstructions => _s(raw['specialInstructions']);
  num? get estimatedAmount => _n(raw['estimatedAmount']);
  Json? get assignedVehicle => raw['assignedVehicle'] is Json ? raw['assignedVehicle'] as Json : null;
  Json? get assignedDriver => raw['assignedDriver'] is Json ? raw['assignedDriver'] as Json : null;
  Json? get trip => raw['trip'] is Json ? raw['trip'] as Json : null;
  List<Json> get events => _l(trip?['events']);
  List<Json> get activities => _l(raw['activities']);
  dynamic get createdAt => raw['createdAt'];
  String? get cancelReason => _s(raw['cancelReason']);
  num? get fromLatitude => _n(raw['fromLatitude']);
  num? get fromLongitude => _n(raw['fromLongitude']);
  num? get toLatitude => _n(raw['toLatitude']);
  num? get toLongitude => _n(raw['toLongitude']);
}

class Booking {
  Booking(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get code => _s(raw['code']) ?? '';
  dynamic get date => raw['date'];
  String get employeeName => _s(raw['employeeName']) ?? '';
  String? get employeeMobile => _s(raw['employeeMobile']);
  String? get employeeEmail => _s(raw['employeeEmail']);
  String? get clientName => _s(raw['clientName']);
  String? get clientId => _s(raw['clientId']);
  String get tripType => _s(raw['tripType']) ?? 'REGULAR';
  String get tripTypeLabel => tripType == 'ADHOC' ? 'Ad-hoc' : 'Regular';
  String get fromLocation => _s(raw['fromLocation']) ?? '';
  String get toLocation => _s(raw['toLocation']) ?? '';
  int get passengers => _i(raw['passengers'], 1);
  String? get vehicleType => _s(raw['vehicleType']);
  Json? get vehicle => raw['vehicle'] is Json ? raw['vehicle'] as Json : null;
  Json? get driver => raw['driver'] is Json ? raw['driver'] as Json : null;
  PlatformInfo? get platform => raw['platform'] is Json ? PlatformInfo(raw['platform'] as Json) : null;
  String get status => _s(raw['status']) ?? '';
  num? get estimatedAmount => _n(raw['estimatedAmount']);
  Json? get trip => raw['trip'] is Json ? raw['trip'] as Json : null;
  List<Json> get activities => _l(raw['activities']);
  Json? get supervisor => raw['supervisor'] is Json ? raw['supervisor'] as Json : null;
  String? get notes => _s(raw['notes']);
  String? get cancelReason => _s(raw['cancelReason']);
}

class Trip {
  Trip(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get code => _s(raw['code']) ?? '';
  String get status => _s(raw['status']) ?? '';
  Json get driver => _j(raw['driver']);
  Json get vehicle => _j(raw['vehicle']);
  PlatformInfo? get platform => raw['platform'] is Json ? PlatformInfo(raw['platform'] as Json) : null;
  String get platformName => platform?.name ?? 'Other';
  Json? get supervisor => raw['supervisor'] is Json ? raw['supervisor'] as Json : null;
  String? get clientName => _s(raw['clientName']);
  String get fromLocation => _s(raw['fromLocation']) ?? '';
  String get toLocation => _s(raw['toLocation']) ?? '';
  dynamic get scheduledStart => raw['scheduledStart'];
  String? get loginTime => _s(raw['loginTime']);
  String? get reportingTime => _s(raw['reportingTime']);
  dynamic get startedAt => raw['startedAt'];
  dynamic get completedAt => raw['completedAt'];
  String get vehicleType => _s(raw['vehicleType']) ?? '';
  int? get modelYearMin => _n(raw['modelYearMin'])?.toInt();
  String get bookingType => _s(raw['bookingType']) ?? 'INSTANT';
  int get passengers => _i(raw['passengers'], 1);
  num? get amount => _n(raw['amount']);
  bool? get onTime => raw['onTime'] as bool?;
  String? get externalTripId => _s(raw['externalTripId']);
  String? get adhocCode => _s(raw['adhocCode']);
  String? get bookingCode => _s(raw['bookingCode']);
  List<Json> get events => _l(raw['events']);
  bool get isLive => const ['ACCEPTED', 'YET_TO_START', 'ON_TRIP', 'DELAYED'].contains(status);
}

class AppNotification {
  AppNotification(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  String get type => _s(raw['type']) ?? 'SYSTEM';
  String get title => _s(raw['title']) ?? '';
  String get body => _s(raw['body']) ?? '';
  bool get read => raw['read'] == true;
  dynamic get createdAt => raw['createdAt'];
  Json get data => _j(raw['data']);
}

class Earning {
  Earning(this.raw);
  final Json raw;
  String get id => _s(raw['id']) ?? '';
  num get amount => _n(raw['amount']) ?? 0;
  dynamic get date => raw['date'];
  String get status => _s(raw['status']) ?? 'PENDING';
  String? get tripCode => _s(raw['tripCode']);
  String? get vehicleType => _s(raw['vehicleType']);
  String get platform => _s(raw['platform']) ?? 'Other';
  String? get platformColor => _s(raw['platformColor']);
  String? get fromLocation => _s(raw['fromLocation']);
  String? get toLocation => _s(raw['toLocation']);
}
