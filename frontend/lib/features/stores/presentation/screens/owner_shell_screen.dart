import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/state/store_cubit.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../categories/data/datasources/categories_remote_data_source.dart';
import '../../../categories/data/repositories/categories_repository_impl.dart';
import '../../../items/data/datasources/items_remote_data_source.dart';
import '../../../items/data/repositories/items_repository_impl.dart';
import '../../../offers/data/datasources/offers_remote_data_source.dart';
import '../../../offers/data/repositories/offers_repository_impl.dart';
import '../../data/datasources/owner_profile_remote_data_source.dart';
import '../../data/repositories/owner_profile_repository_impl.dart';
import '../controllers/edit_owner_profile_controller.dart';
import '../controllers/owner_add_controller.dart';
import '../controllers/owner_catalog_controller.dart';
import '../controllers/owner_offers_controller.dart';
import '../controllers/owner_profile_controller.dart';
import '../services/owner_chat_service.dart';
import '../services/owner_notifications_service.dart';
import '../screens/edit_owner_profile_screen.dart';
import '../../../guest/presentation/screens/guest_shell_screen.dart';
import '../theme/owner_theme.dart';
import 'tabs/owner_add_tab.dart';
import 'tabs/owner_chat_tab.dart';
import 'tabs/owner_catalog_tab.dart';
import 'tabs/owner_offers_tab.dart';
import 'tabs/owner_profile_tab.dart';
import 'tabs/owner_scan_qr_tab.dart';

class OwnerShellScreen extends StatefulWidget {
	const OwnerShellScreen({super.key});

	@override
	State<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends State<OwnerShellScreen> {
	final SecureStorage _secureStorage = SecureStorage();
	late final ApiClient _apiClient;
	late final OwnerCatalogController _catalogController;
	late final OwnerAddController _addController;
	late final OwnerOffersController _offersController;
	late final OwnerProfileController _profileController;
	late final EditOwnerProfileController _editProfileController;
	late final OwnerNotificationsService _ownerNotificationsService;
	Timer? _notificationsTimer;
	List<OwnerConversationNotification> _ownerConversationNotifications =
		const <OwnerConversationNotification>[];
	int _ownerUnreadCount = 0;
	bool _isFetchingOwnerNotifications = false;
	int _index = 0;
	bool _isDarkMode = true;

	@override
	void initState() {
		super.initState();
		_apiClient = ApiClient(secureStorage: _secureStorage);

		final categoriesRepository = CategoriesRepositoryImpl(
			remoteDataSource: CategoriesRemoteDataSource(apiClient: _apiClient),
		);
		final itemsRepository = ItemsRepositoryImpl(
			remoteDataSource: ItemsRemoteDataSource(apiClient: _apiClient),
		);
		final offersRepository = OffersRepositoryImpl(
			remoteDataSource: OffersRemoteDataSource(apiClient: _apiClient),
		);

		_catalogController = OwnerCatalogController(
			itemsRepository: itemsRepository,
			categoriesRepository: categoriesRepository,
			offersRepository: offersRepository,
		);
		_addController = OwnerAddController(categoriesRepository: categoriesRepository);
		_offersController = OwnerOffersController(offersRepository: offersRepository);
		_profileController = OwnerProfileController(secureStorage: _secureStorage);
		_profileController.load();

		final profileRepository = OwnerProfileRepositoryImpl(
			remoteDataSource: OwnerProfileRemoteDataSource(apiClient: _apiClient),
		);
		_editProfileController = EditOwnerProfileController(
			profileRepository: profileRepository,
			secureStorage: _secureStorage,
		);
		_ownerNotificationsService = OwnerNotificationsService(apiClient: _apiClient);
		_loadThemePreference();
		_refreshOwnerNotifications();
		_startOwnerNotificationsPolling();
	}

	void _startOwnerNotificationsPolling() {
		_notificationsTimer?.cancel();
		_notificationsTimer = Timer.periodic(const Duration(seconds: 20), (_) {
			_refreshOwnerNotifications();
		});
	}

	Future<void> _refreshOwnerNotifications() async {
		if (_isFetchingOwnerNotifications) {
			return;
		}

		_isFetchingOwnerNotifications = true;
		try {
			final notifications = await _ownerNotificationsService.listConversationNotifications();
			final unreadCount = notifications.fold<int>(
				0,
				(sum, item) => sum + item.unreadCount,
			);

			if (!mounted) {
				return;
			}

			setState(() {
				_ownerConversationNotifications = notifications;
				_ownerUnreadCount = unreadCount;
			});
		} catch (_) {
			// Ignore transient polling failures and keep last known state.
		} finally {
			_isFetchingOwnerNotifications = false;
		}
	}

	Future<void> _openOwnerNotificationsSheet() async {
		await _refreshOwnerNotifications();

		if (!mounted) {
			return;
		}

		await showModalBottomSheet<void>(
			context: context,
			showDragHandle: true,
			builder: (sheetContext) {
				final items = _ownerConversationNotifications
					.where((notification) => notification.unreadCount > 0)
					.toList(growable: false);

				if (items.isEmpty) {
					return const _OwnerNotificationsEmptyState();
				}

				return _OwnerNotificationsList(
					items: items,
					onTapItem: (notification) async {
						Navigator.of(sheetContext).pop();
						await _ownerNotificationsService.markConversationAsRead(
							notification.conversationId,
						);
						if (!mounted) {
							return;
						}
						await _openOwnerConversation(notification);
						await _refreshOwnerNotifications();
					},
				);
			},
		);
	}

	Future<void> _openOwnerConversation(OwnerConversationNotification notification) async {
		if (!mounted) {
			return;
		}

		final changed = await Navigator.of(context).push<bool>(
			MaterialPageRoute<bool>(
				builder: (_) => OwnerConversationScreen(
					conversation: notification,
					service: OwnerChatService(apiClient: _apiClient),
				),
			),
		);

		if (changed == true) {
			await _refreshOwnerNotifications();
		}
	}

	Future<void> _loadThemePreference() async {
		final savedMode = await _secureStorage.getOwnerThemeMode();
		if (!mounted) {
			return;
		}

		setState(() {
			_isDarkMode = savedMode != 'light';
		});
	}

	Future<void> _setThemeMode(bool isDarkMode) async {
		if (!mounted) {
			return;
		}

		setState(() {
			_isDarkMode = isDarkMode;
		});

		await _secureStorage.saveOwnerThemeMode(isDarkMode ? 'dark' : 'light');
	}

	@override
	void dispose() {
		_notificationsTimer?.cancel();
		_catalogController.dispose();
		_addController.dispose();
		_offersController.dispose();
		_profileController.dispose();
		_editProfileController.dispose();
		super.dispose();
	}

	Future<void> _logout() async {
		final authState = context.read<AuthState>();
		final cartState = context.read<CartState>();
		final storeCubit = context.read<StoreCubit>();

		await _apiClient.resetSessionHeaders();
		await _secureStorage.clearSession();
		cartState.clear();
		storeCubit.clearCurrentStore();
		await authState.setUnauthenticated();

		if (!mounted) {
			return;
		}

		await Navigator.pushAndRemoveUntil<void>(
			context,
			MaterialPageRoute<void>(builder: (_) => const GuestShellScreen()),
			(route) => false,
		);
	}

	Future<void> _openEditProfile() async {
		if (!mounted) {
			return;
		}

		final currentTheme = Theme.of(context);
		final result = await Navigator.push<bool>(
			context,
			MaterialPageRoute<bool>(
				builder: (_) => Theme(
					data: currentTheme,
					child: EditOwnerProfileScreen(
						controller: _editProfileController,
					),
				),
			),
		);

		if (!mounted) {
			return;
		}

		if (result == true) {
			// Profile was updated, refresh the profile data
			_profileController.refresh();
		}
	}

	void _refreshCatalogAfterAdd() {
		_catalogController.load();
	}

	@override
	Widget build(BuildContext context) {
		final tabs = <Widget>[
			OwnerCatalogTab(
				controller: _catalogController,
				onUnauthorized: _logout,
			),
			OwnerAddTab(
				controller: _addController,
				onItemCreated: _refreshCatalogAfterAdd,
				onUnauthorized: _logout,
			),
			OwnerOffersTab(
				controller: _offersController,
				onUnauthorized: _logout,
			),
			OwnerChatTab(onUnauthorized: _logout),
			const OwnerScanQrTab(),
			OwnerProfileTab(
				controller: _profileController,
				onLogout: _logout,
				onEditProfile: _openEditProfile,
				isDarkMode: _isDarkMode,
				onThemeModeChanged: _setThemeMode,
			),
		];
		final theme = OwnerTheme.themeForMode(
			_isDarkMode ? Brightness.dark : Brightness.light,
		);
		final palette = OwnerTheme.paletteForBrightness(
			_isDarkMode ? Brightness.dark : Brightness.light,
		);

		return Theme(
			data: theme,
			child: Scaffold(
				backgroundColor: palette.background,
				body: Stack(
					children: [
						Positioned(
							top: -120,
							right: -80,
							child: Container(
								width: 320,
								height: 320,
								decoration: BoxDecoration(
									shape: BoxShape.circle,
									gradient: RadialGradient(
										colors: [
											palette.primary.withValues(alpha: 0.22),
											Colors.transparent,
										],
									),
								),
							),
						),
						Positioned(
							bottom: 120,
							left: -90,
							child: Container(
								width: 260,
								height: 260,
								decoration: BoxDecoration(
									shape: BoxShape.circle,
									gradient: RadialGradient(
										colors: [
											palette.secondary.withValues(alpha: 0.18),
											Colors.transparent,
										],
									),
								),
							),
						),
						SafeArea(
							top: false,
							child: Stack(
								children: [
									Positioned.fill(
										child: IndexedStack(index: _index, children: tabs),
									),
									if (_ownerUnreadCount > 0)
										Positioned(
											top: MediaQuery.of(context).padding.top + 8,
											right: 12,
											child: _OwnerNotificationsBell(
												palette: palette,
												unreadCount: _ownerUnreadCount,
												onTap: _openOwnerNotificationsSheet,
											),
										),
								],
							),
						),
					],
				),
				bottomNavigationBar: SafeArea(
					top: false,
					minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
					child: ClipRRect(
						borderRadius: BorderRadius.circular(22),
						child: Container(
							decoration: BoxDecoration(
								color: palette.surface.withValues(alpha: 0.94),
								border: Border.all(color: palette.border),
								boxShadow: [
									BoxShadow(
										color: Colors.black.withValues(alpha: palette.isDark ? 0.26 : 0.08),
										blurRadius: 20,
										offset: const Offset(0, 10),
									),
								],
							),
							child: BottomNavigationBar(
								currentIndex: _index,
								onTap: (value) {
									setState(() => _index = value);
									if (value == 0) {
										_catalogController.load();
									}
									if (value == 1) {
										_addController.load();
									}
									if (value == 2) {
										_offersController.load();
									}
									if (value == 5) {
										_profileController.load();
									}
								},
								type: BottomNavigationBarType.fixed,
								backgroundColor: Colors.transparent,
								selectedItemColor: palette.primary,
								unselectedItemColor: palette.onSurfaceMuted,
								showUnselectedLabels: true,
								items: [
									BottomNavigationBarItem(
										icon: const Icon(Icons.grid_view_rounded),
										label: 'Catalog',
									),
									BottomNavigationBarItem(
										icon: const Icon(Icons.add_circle_outline_rounded),
										label: 'Add',
									),
									BottomNavigationBarItem(
										icon: const Icon(Icons.local_offer_outlined),
										label: 'Offers',
									),
									BottomNavigationBarItem(
										icon: _OwnerChatNavIcon(unreadCount: _ownerUnreadCount),
										label: 'Chat',
									),
									BottomNavigationBarItem(
										icon: const Icon(Icons.qr_code_scanner_rounded),
										label: 'Scan QR',
									),
									BottomNavigationBarItem(
										icon: _OwnerProfileNavIcon(
											palette: palette,
											ownerName: _profileController.ownerName,
										),
										label: '',
									),
								],
							),
						),
					),
				),
			),
		);
	}
}

class _OwnerProfileNavIcon extends StatelessWidget {
	const _OwnerProfileNavIcon({
		required this.palette,
		required this.ownerName,
	});

	final OwnerPalette palette;
	final String ownerName;

	String get _initial {
		final trimmed = ownerName.trim();
		if (trimmed.isEmpty || trimmed.toLowerCase() == 'owner') {
			return 'O';
		}
		return trimmed.substring(0, 1).toUpperCase();
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			width: 32,
			height: 32,
			decoration: BoxDecoration(
				shape: BoxShape.circle,
				gradient: LinearGradient(
					colors: [palette.primary, palette.secondary],
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
				),
				border: Border.all(color: palette.border.withValues(alpha: 0.45)),
			),
			alignment: Alignment.center,
			child: Text(
				_initial,
				style: const TextStyle(
					color: Colors.white,
					fontWeight: FontWeight.w800,
					fontSize: 12,
				),
			),
		);
	}
}

class _OwnerChatNavIcon extends StatelessWidget {
	const _OwnerChatNavIcon({required this.unreadCount});

	final int unreadCount;

	@override
	Widget build(BuildContext context) {
		return Stack(
			clipBehavior: Clip.none,
			children: [
				const Icon(Icons.forum_outlined),
				if (unreadCount > 0)
					Positioned(
						right: -8,
						top: -6,
						child: Container(
							padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
							decoration: BoxDecoration(
								color: const Color(0xFFEF4444),
								borderRadius: BorderRadius.circular(999),
							),
							child: Text(
								unreadCount > 99 ? '99+' : unreadCount.toString(),
								style: const TextStyle(
									fontSize: 10,
									fontWeight: FontWeight.w700,
									color: Colors.white,
								),
							),
						),
					),
			],
		);
	}
}

class _OwnerNotificationsBell extends StatelessWidget {
	const _OwnerNotificationsBell({
		required this.palette,
		required this.unreadCount,
		required this.onTap,
	});

	final OwnerPalette palette;
	final int unreadCount;
	final Future<void> Function() onTap;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: Colors.transparent,
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(14),
				child: Container(
					padding: const EdgeInsets.all(10),
					decoration: BoxDecoration(
						color: palette.surface.withValues(alpha: 0.94),
						borderRadius: BorderRadius.circular(14),
						border: Border.all(
							color: palette.border,
						),
					),
					child: Stack(
						clipBehavior: Clip.none,
						children: [
							Icon(
								Icons.notifications_none_rounded,
								color: palette.onSurface,
							),
							if (unreadCount > 0)
								Positioned(
									right: -6,
									top: -6,
									child: Container(
										padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
										decoration: BoxDecoration(
											color: const Color(0xFFEF4444),
											borderRadius: BorderRadius.circular(999),
										),
										child: Text(
											unreadCount > 99 ? '99+' : unreadCount.toString(),
											style: const TextStyle(
												color: Colors.white,
												fontSize: 11,
												fontWeight: FontWeight.w700,
											),
										),
									),
								),
						],
					),
				),
			),
		);
	}
}

class _OwnerNotificationsEmptyState extends StatelessWidget {
	const _OwnerNotificationsEmptyState();

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			height: 220,
			child: Center(
				child: Text(
					'No unread messages right now',
					style: Theme.of(context).textTheme.bodyMedium,
				),
			),
		);
	}
}

class _OwnerNotificationsList extends StatelessWidget {
	const _OwnerNotificationsList({
		required this.items,
		required this.onTapItem,
	});

	final List<OwnerConversationNotification> items;
	final Future<void> Function(OwnerConversationNotification notification) onTapItem;

	@override
	Widget build(BuildContext context) {
		return ListView.separated(
			padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
			itemCount: items.length,
			separatorBuilder: (_, __) => const SizedBox(height: 8),
			itemBuilder: (context, index) {
				final item = items[index];
				return Card(
					margin: EdgeInsets.zero,
					child: ListTile(
						onTap: () async {
							await onTapItem(item);
						},
						title: Text(
							item.endUserName,
							maxLines: 1,
							overflow: TextOverflow.ellipsis,
						),
						subtitle: Text(
							item.lastMessagePreview?.trim().isNotEmpty == true
								? item.lastMessagePreview!.trim()
								: 'New message',
							maxLines: 2,
							overflow: TextOverflow.ellipsis,
						),
						trailing: CircleAvatar(
							radius: 13,
							backgroundColor: const Color(0xFFEF4444),
							child: Text(
								item.unreadCount > 99 ? '99+' : item.unreadCount.toString(),
								style: const TextStyle(
									fontSize: 10,
									fontWeight: FontWeight.w700,
									color: Colors.white,
								),
							),
						),
					),
				);
			},
		);
	}
}
