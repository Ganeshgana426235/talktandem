import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/auth_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myState = auth.userData?['state'] as String? ?? '';
    final myUid = auth.uid ?? '';
    final textPrimary = AppTheme.getTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);

    final stateLabel =
        myState.isNotEmpty ? 'State ($myState)' : 'State Rankings';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Leaderboard',
              style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          backgroundColor: surfaceColor,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: AppTheme.amberPremium,
            labelColor: AppTheme.amberPremium,
            unselectedLabelColor: textSecondary,
            tabs: const [
              Tab(text: 'National'),
              Tab(text: 'State'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RankingList(scope: 'national', myUid: myUid),
            _RankingList(
              scope: 'state',
              stateFilter: myState,
              stateLabel: stateLabel,
              myUid: myUid,
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final String scope;
  final String? stateFilter;
  final String? stateLabel;
  final String myUid;

  const _RankingList({
    required this.scope,
    required this.myUid,
    this.stateFilter,
    this.stateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return StreamBuilder<List<LeaderboardEntry>>(
      stream: auth.firestore.watchLeaderboard(
        limit: 20,
        stateFilter: scope == 'state' && (stateFilter?.isNotEmpty ?? false)
            ? stateFilter
            : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.tealAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load leaderboard.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary),
              ),
            ),
          );
        }

        final rankings = snapshot.data ?? [];

        if (scope == 'state' && (stateFilter == null || stateFilter!.isEmpty)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.mapPin,
                      size: 48, color: AppTheme.tealAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Add your city/state in Profile to see state rankings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }

        if (rankings.isEmpty) {
          return Center(
            child: Text(
              scope == 'state'
                  ? 'No learners in ${stateLabel ?? 'your state'} yet.'
                  : 'No rankings yet. Be the first!',
              style: TextStyle(color: textSecondary),
            ),
          );
        }

        // --- Premium Sticky Scorecard calculations ---
        final myRankIndex = rankings.indexWhere((e) => e.uid == myUid);
        final rankText = myRankIndex != -1 ? "#${myRankIndex + 1}" : "-";
        
        final myUserData = auth.userData;
        final myName = myUserData?['name'] as String? ?? 'You';
        final myXp = myUserData?['xp'] as num? ?? 0;
        final myStreak = myUserData?['streak'] as num? ?? 0;
        final myAvatar = myUserData?['avatarUrl'] as String?;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: rankings.length,
                itemBuilder: (context, index) {
                  final user = rankings[index];
                  final isMe = user.uid == myUid;
                  final isTop3 = index < 3;

                  Color borderCol = Colors.transparent;
                  if (index == 0) borderCol = const Color(0xFFFFD700);
                  if (index == 1) borderCol = const Color(0xFFC0C0C0);
                  if (index == 2) borderCol = const Color(0xFFCD7F32);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppTheme.tealAccent.withValues(alpha: 0.08)
                          : surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMe
                            ? AppTheme.tealAccent
                            : (isTop3 ? borderCol : borderColor),
                        width: isMe || isTop3 ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: isTop3 ? borderCol : textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 16),
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                              ? (user.avatarUrl!.startsWith('http')
                                  ? NetworkImage(user.avatarUrl!)
                                  : AssetImage(user.avatarUrl!) as ImageProvider)
                              : null,
                          backgroundColor: AppTheme.tealAccent,
                          child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                              ? Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.tealAccent
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'You',
                                        style: TextStyle(
                                          color: AppTheme.tealAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(LucideIcons.flame,
                                      color: AppTheme.amberPremium, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${user.streak} Day Streak',
                                    style: TextStyle(
                                        color: textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total XP',
                                style: TextStyle(color: textSecondary, fontSize: 10)),
                            Text(
                              '${user.xp}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.tealAccent,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // --- Sticky Personal Score Card at the bottom ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(color: AppTheme.getBorderColor(context), width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Text(
                      myRankIndex != -1 ? rankText : "ME",
                      style: const TextStyle(
                        color: AppTheme.amberPremium,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: myAvatar != null && myAvatar.isNotEmpty
                          ? (myAvatar.startsWith('http')
                              ? NetworkImage(myAvatar)
                              : AssetImage(myAvatar) as ImageProvider)
                          : null,
                      backgroundColor: AppTheme.tealAccent,
                      child: (myAvatar == null || myAvatar.isEmpty)
                          ? Text(
                              myName.isNotEmpty ? myName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$myName (My Rank)",
                            style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(LucideIcons.flame, color: AppTheme.amberPremium, size: 14),
                              const SizedBox(width: 4),
                              Text('$myStreak Day Streak', style: TextStyle(color: textSecondary, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total XP', style: TextStyle(color: textSecondary, fontSize: 10)),
                        Text(
                          '$myXp XP',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.tealAccent,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
