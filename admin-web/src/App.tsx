import { useCallback, useState } from "react";
import { ExportModal } from "./components/ExportModal";
import { Layout } from "./components/Layout";
import type { AdminTab } from "./components/Tabs";
import { useAuth } from "./hooks/useAuth";
import { useCollections } from "./hooks/useCollections";
import { useCommunity } from "./hooks/useCommunity";
import { useFeedback } from "./hooks/useFeedback";
import { useGifticons } from "./hooks/useGifticons";
import { useMetrics } from "./hooks/useMetrics";
import { useRestaurants } from "./hooks/useRestaurants";
import { CollectionsPage } from "./pages/CollectionsPage";
import { CommunityAdminPage } from "./pages/CommunityAdminPage";
import { DashboardPage } from "./pages/DashboardPage";
import { FeedbackPage } from "./pages/FeedbackPage";
import { GifticonsPage } from "./pages/GifticonsPage";
import { LoginPage } from "./pages/LoginPage";
import { MapRegisterPage } from "./pages/MapRegisterPage";
import { OwnerApplicationsPage } from "./pages/OwnerApplicationsPage";
import { PopularityPage } from "./pages/PopularityPage";
import { PushSettingsPage } from "./pages/PushSettingsPage";
import { RestaurantsPage } from "./pages/RestaurantsPage";
import { UsersPage } from "./pages/UsersPage";
import { useOwnerApplications } from "./hooks/useOwnerApplications";
import { usePushConfig } from "./hooks/usePushConfig";
import { useUsers } from "./hooks/useUsers";

export default function App() {
  const auth = useAuth();
  const enabled = auth.isAdmin && !auth.loading;
  const [tab, setTab] = useState<AdminTab>("metrics");
  const [showExport, setShowExport] = useState(false);

  const metricsState = useMetrics(enabled);
  const restaurantsState = useRestaurants(enabled);
  const gifticonsState = useGifticons(enabled && tab === "gifticons");
  const feedbackState = useFeedback(enabled && tab === "feedback");
  const communityState = useCommunity(enabled && tab === "community");
  const collectionsState = useCollections(enabled && tab === "collections");
  const usersState = useUsers(enabled && tab === "users");
  const pushConfigState = usePushConfig(enabled && tab === "push");
  const ownerApplicationsState = useOwnerApplications(
    enabled && tab === "owner_applications",
  );

  const refreshAll = useCallback(async () => {
    await Promise.all([
      metricsState.reload(),
      restaurantsState.reload(),
      tab === "gifticons" ? gifticonsState.reload() : Promise.resolve(),
      tab === "feedback" ? feedbackState.reload() : Promise.resolve(),
      tab === "community" ? communityState.reload() : Promise.resolve(),
      tab === "collections" ? collectionsState.reload() : Promise.resolve(),
      tab === "users" ? usersState.reload() : Promise.resolve(),
      tab === "push" ? pushConfigState.reload() : Promise.resolve(),
      tab === "owner_applications"
        ? ownerApplicationsState.reload()
        : Promise.resolve(),
    ]);
  }, [
    metricsState,
    restaurantsState,
    gifticonsState,
    feedbackState,
    communityState,
    collectionsState,
    usersState,
    pushConfigState,
    ownerApplicationsState,
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
      if (metricsState.error) {
        return <div className="alert">{metricsState.error}</div>;
      }
      if (!metricsState.metrics) {
        return (
          <div className="center-msg">
            {metricsState.loading ? "지표 불러오는 중…" : "지표를 불러올 수 없습니다."}
          </div>
        );
      }
      return (
        <DashboardPage
          metrics={metricsState.metrics}
          restaurants={restaurantsState.restaurants}
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
          bannedWords={communityState.bannedWords}
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
          onAddWord={communityState.addWord}
          onRemoveWord={communityState.removeWord}
          onAddNotice={communityState.addNotice}
          onEditNotice={communityState.editNotice}
          onToggleNoticeActive={communityState.toggleNoticeActive}
          onRemoveNotice={communityState.removeNotice}
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
          nicknameBannedWords={usersState.nicknameBannedWords}
          nicknameReservedWords={usersState.nicknameReservedWords}
          loading={usersState.loading}
          error={usersState.error}
          onReload={usersState.reload}
          onAddNicknameWord={usersState.addNicknameWord}
          onRemoveNicknameWord={usersState.removeNicknameWord}
          onAddReservedWord={usersState.addReservedWord}
          onRemoveReservedWord={usersState.removeReservedWord}
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
          if (next === "gifticons") gifticonsState.reload();
          if (next === "feedback") feedbackState.reload();
          if (next === "community") communityState.reload();
          if (next === "collections") collectionsState.reload();
          if (next === "users") usersState.reload();
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

      {showExport && metricsState.metrics && (
        <ExportModal
          metrics={metricsState.metrics}
          restaurants={restaurantsState.restaurants}
          onClose={() => setShowExport(false)}
        />
      )}
    </>
  );
}
