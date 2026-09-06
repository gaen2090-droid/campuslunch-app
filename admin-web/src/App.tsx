import { useCallback, useState } from "react";
import { ExportModal } from "./components/ExportModal";
import { Layout } from "./components/Layout";
import type { AdminTab } from "./components/Tabs";
import { TrustExportModal } from "./components/TrustExportModal";
import { useAuth } from "./hooks/useAuth";
import { useCollections } from "./hooks/useCollections";
import { useCommunity } from "./hooks/useCommunity";
import { useFeedback } from "./hooks/useFeedback";
import { useGifticons } from "./hooks/useGifticons";
import { useKpiMetrics } from "./hooks/useKpiMetrics";
import { useKpiTargets } from "./hooks/useKpiTargets";
import { useMetrics } from "./hooks/useMetrics";
import { useOpsMetrics } from "./hooks/useOpsMetrics";
import { useRealtimeMetrics } from "./hooks/useRealtimeMetrics";
import { useRestaurants } from "./hooks/useRestaurants";
import { useOwnerApplications } from "./hooks/useOwnerApplications";
import { usePushConfig } from "./hooks/usePushConfig";
import { useTrustSignals } from "./hooks/useTrustAbuse";
import { useUsers } from "./hooks/useUsers";
import { CollectionsPage } from "./pages/CollectionsPage";
import { CommunityAdminPage } from "./pages/CommunityAdminPage";
import { CommunityBannedWordsPage } from "./pages/CommunityBannedWordsPage";
import { NicknameWordsPage } from "./pages/NicknameWordsPage";
import { DashboardPage } from "./pages/DashboardPage";
import { FeedbackPage } from "./pages/FeedbackPage";
import { GifticonsPage } from "./pages/GifticonsPage";
import { KPIPage } from "./pages/KPIPage";
import { LoginPage } from "./pages/LoginPage";
import { MapRegisterPage } from "./pages/MapRegisterPage";
import { OwnerApplicationsPage } from "./pages/OwnerApplicationsPage";
import { OpsPage } from "./pages/OpsPage";
import { PopularityPage } from "./pages/PopularityPage";
import { PushSettingsPage } from "./pages/PushSettingsPage";
import { RestaurantsPage } from "./pages/RestaurantsPage";
import { TrustSignalsPage } from "./pages/TrustAbusePage";
import { UsersPage } from "./pages/UsersPage";

export default function App() {
  const auth = useAuth();
  const enabled = auth.isAdmin && !auth.loading;
  const [tab, setTab] = useState<AdminTab>("metrics");
  const [showExport, setShowExport] = useState(false);
  const [showTrustExport, setShowTrustExport] = useState(false);

  const metricsState = useMetrics(enabled);
  const realtimeMetricsState = useRealtimeMetrics(enabled && tab === "metrics");
  const opsMetricsState = useOpsMetrics(enabled && tab === "ops");
  const restaurantsState = useRestaurants(enabled);
  const gifticonsState = useGifticons(enabled && tab === "gifticons");
  const feedbackState = useFeedback(enabled && tab === "feedback");
  const communityState = useCommunity(
    enabled && (tab === "community" || tab === "community_banned_words"),
  );
  const collectionsState = useCollections(enabled && tab === "collections");
  const usersState = useUsers(
    enabled && (tab === "users" || tab === "nickname_words" || tab === "kpi"),
  );
  const trustSignalsState = useTrustSignals(
    enabled && tab === "trust_signals",
  );
  const pushConfigState = usePushConfig(enabled && tab === "push");
  const ownerApplicationsState = useOwnerApplications(
    enabled && (tab === "owner_applications" || tab === "kpi"),
  );
  const kpiMetricsState = useKpiMetrics(enabled && tab === "kpi");
  const kpiTargetsState = useKpiTargets(enabled && tab === "kpi");

  const refreshAll = useCallback(async () => {
    await Promise.all([
      metricsState.reload(),
      restaurantsState.reload(),
      tab === "metrics" ? realtimeMetricsState.reload() : Promise.resolve(),
      tab === "ops" ? opsMetricsState.reload() : Promise.resolve(),
      tab === "gifticons" ? gifticonsState.reload() : Promise.resolve(),
      tab === "feedback" ? feedbackState.reload() : Promise.resolve(),
      tab === "community" ? communityState.reload() : Promise.resolve(),
      tab === "collections" ? collectionsState.reload() : Promise.resolve(),
      tab === "users" ? usersState.reload() : Promise.resolve(),
      tab === "trust_signals" ? trustSignalsState.reload() : Promise.resolve(),
      tab === "push" ? pushConfigState.reload() : Promise.resolve(),
      tab === "owner_applications" || tab === "kpi"
        ? ownerApplicationsState.reload()
        : Promise.resolve(),
      tab === "kpi" ? kpiMetricsState.reload() : Promise.resolve(),
      tab === "kpi" ? kpiTargetsState.reload() : Promise.resolve(),
      tab === "kpi" ? usersState.reload() : Promise.resolve(),
    ]);
  }, [
    metricsState,
    realtimeMetricsState,
    opsMetricsState,
    restaurantsState,
    gifticonsState,
    feedbackState,
    communityState,
    collectionsState,
    usersState,
    trustSignalsState,
    pushConfigState,
    ownerApplicationsState,
    kpiMetricsState,
    kpiTargetsState,
    tab,
  ]);

  if (auth.loading) {
    return <div className="center-msg">불러오는 중…</div>;
  }

  if (!auth.session || !auth.isAdmin) {
    return <LoginPage onSignIn={auth.signIn} error={auth.error} />;
  }

  const loading =
    metricsState.loading ||
    (tab !== "gifticons" && restaurantsState.loading);

  function renderContent() {
    if (tab === "metrics") {
      if (realtimeMetricsState.error) {
        return <div className="alert">{realtimeMetricsState.error}</div>;
      }
      if (!realtimeMetricsState.metrics) {
        return (
          <div className="center-msg">
            {realtimeMetricsState.loading
              ? "지표 불러오는 중…"
              : "지표를 불러올 수 없습니다."}
          </div>
        );
      }
      return <DashboardPage metrics={realtimeMetricsState.metrics} />;
    }

    if (tab === "kpi") {
      return (
        <KPIPage
          users={usersState.users}
          restaurants={restaurantsState.restaurants}
          ownerApplications={ownerApplicationsState.applications}
          kpiMetrics={kpiMetricsState.kpiMetrics}
          targets={kpiTargetsState.targets}
          onSaveTarget={kpiTargetsState.saveTarget}
        />
      );
    }

    if (tab === "ops") {
      return (
        <OpsPage
          metrics={opsMetricsState.metrics}
          loading={opsMetricsState.loading}
          error={opsMetricsState.error}
        />
      );
    }

    if (restaurantsState.error) {
      return <div className="alert">{restaurantsState.error}</div>;
    }

    if (tab === "restaurants") {
      return (
        <RestaurantsPage
          restaurants={restaurantsState.restaurants}
          onReload={restaurantsState.reload}
        />
      );
    }

    if (tab === "popularity") {
      return (
        <PopularityPage
          restaurants={restaurantsState.restaurants}
          onReload={restaurantsState.reload}
        />
      );
    }

    if (tab === "map_register") {
      return <MapRegisterPage onReload={restaurantsState.reload} />;
    }

    if (tab === "feedback") {
      return (
        <FeedbackPage
          feedback={feedbackState.feedback}
          loading={feedbackState.loading}
          error={feedbackState.error}
        />
      );
    }

    if (tab === "community") {
      return (
        <CommunityAdminPage
          reports={communityState.reports}
          posts={communityState.posts}
          notices={communityState.notices}
          loading={communityState.loading}
          error={communityState.error}
          pinnedPosts={communityState.pinnedPosts}
          postQuery={communityState.postQuery}
          onSearchPosts={communityState.searchPosts}
          onHidePost={communityState.hidePost}
          onRemovePost={communityState.removePost}
          onSetPostPinned={communityState.setPostPinned}
          onReorderPinned={communityState.reorderPinned}
          onHideComment={communityState.hideComment}
          onRemoveComment={communityState.removeComment}
          onAddNotice={communityState.addNotice}
          onEditNotice={communityState.editNotice}
          onToggleNoticeActive={communityState.toggleNoticeActive}
          onRemoveNotice={communityState.removeNotice}
        />
      );
    }

    if (tab === "community_banned_words") {
      return (
        <CommunityBannedWordsPage
          bannedWords={communityState.bannedWords}
          onAddWord={communityState.addWord}
          onRemoveWord={communityState.removeWord}
        />
      );
    }

    if (tab === "collections") {
      return (
        <CollectionsPage
          restaurants={restaurantsState.restaurants}
          collections={collectionsState.collections}
          items={collectionsState.items}
          comments={collectionsState.comments}
          loading={collectionsState.loading}
          error={collectionsState.error}
          onAddCollection={collectionsState.addCollection}
          onEditCollection={collectionsState.editCollection}
          onTogglePublished={collectionsState.togglePublished}
          onRemoveCollection={collectionsState.removeCollection}
          onAddItem={collectionsState.addItem}
          onRemoveItem={collectionsState.removeItem}
          onReorderItems={collectionsState.reorderItems}
          onReorderCollections={collectionsState.reorderCollectionsList}
          onHideComment={collectionsState.hideComment}
          onRemoveComment={collectionsState.removeComment}
        />
      );
    }

    if (tab === "users") {
      return (
        <UsersPage
          users={usersState.users}
          loading={usersState.loading}
          error={usersState.error}
          onReload={usersState.reload}
        />
      );
    }

    if (tab === "nickname_words") {
      return (
        <NicknameWordsPage
          nicknameBannedWords={usersState.nicknameBannedWords}
          nicknameReservedWords={usersState.nicknameReservedWords}
          onAddNicknameWord={usersState.addNicknameWord}
          onRemoveNicknameWord={usersState.removeNicknameWord}
          onAddReservedWord={usersState.addReservedWord}
          onRemoveReservedWord={usersState.removeReservedWord}
        />
      );
    }

    if (tab === "trust_signals") {
      return (
        <TrustSignalsPage
          report={trustSignalsState.report}
          days={trustSignalsState.days}
          loading={trustSignalsState.loading}
          error={trustSignalsState.error}
          onReload={trustSignalsState.reload}
          onExport={() => setShowTrustExport(true)}
        />
      );
    }

    if (tab === "push") {
      return (
        <PushSettingsPage
          config={pushConfigState.config}
          loading={pushConfigState.loading}
          error={pushConfigState.error}
          onReload={pushConfigState.reload}
        />
      );
    }

    if (tab === "owner_applications") {
      return (
        <OwnerApplicationsPage
          applications={ownerApplicationsState.applications}
          loading={ownerApplicationsState.loading}
          error={ownerApplicationsState.error}
          onReload={ownerApplicationsState.reload}
        />
      );
    }

    return (
      <GifticonsPage
        gifticons={gifticonsState.gifticons}
        loading={gifticonsState.loading}
        error={gifticonsState.error}
        onReload={gifticonsState.reload}
      />
    );
  }

  return (
    <>
      <Layout
        activeTab={tab}
        onTabChange={(next) => {
          setTab(next);
          if (next === "metrics") realtimeMetricsState.reload();
          if (next === "ops") opsMetricsState.reload();
          if (next === "gifticons") gifticonsState.reload();
          if (next === "feedback") feedbackState.reload();
          if (next === "community") communityState.reload();
          if (next === "community_banned_words") communityState.reload();
          if (next === "collections") collectionsState.reload();
          if (next === "users") usersState.reload();
          if (next === "nickname_words") usersState.reload();
          if (next === "kpi") {
            usersState.reload();
            ownerApplicationsState.reload();
            kpiMetricsState.reload();
            kpiTargetsState.reload();
          }
          if (next === "trust_signals") trustSignalsState.reload();
          if (next === "push") pushConfigState.reload();
          if (next === "owner_applications") ownerApplicationsState.reload();
        }}
        onSignOut={auth.signOut}
        onExport={() => setShowExport(true)}
        updatedAt={metricsState.updatedAt}
        onRefresh={refreshAll}
        refreshing={loading}
      >
        {renderContent()}
      </Layout>

      {showExport && (
        <ExportModal
          restaurants={restaurantsState.restaurants}
          onClose={() => setShowExport(false)}
        />
      )}

      {showTrustExport && trustSignalsState.report && (
        <TrustExportModal
          report={trustSignalsState.report}
          days={trustSignalsState.days}
          onClose={() => setShowTrustExport(false)}
        />
      )}
    </>
  );
}
