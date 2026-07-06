import { useCallback, useState } from "react";
import { ExportModal } from "./components/ExportModal";
import { Layout } from "./components/Layout";
import type { AdminTab } from "./components/Tabs";
import { useAuth } from "./hooks/useAuth";
import { useCommunity } from "./hooks/useCommunity";
import { useFeedback } from "./hooks/useFeedback";
import { useGifticons } from "./hooks/useGifticons";
import { useMetrics } from "./hooks/useMetrics";
import { useRestaurants } from "./hooks/useRestaurants";
import { CommunityAdminPage } from "./pages/CommunityAdminPage";
import { DashboardPage } from "./pages/DashboardPage";
import { FeedbackPage } from "./pages/FeedbackPage";
import { GifticonsPage } from "./pages/GifticonsPage";
import { LoginPage } from "./pages/LoginPage";
import { MapRegisterPage } from "./pages/MapRegisterPage";
import { PopularityPage } from "./pages/PopularityPage";
import { PushSettingsPage } from "./pages/PushSettingsPage";
import { RestaurantsPage } from "./pages/RestaurantsPage";
import { UsersPage } from "./pages/UsersPage";
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
  const usersState = useUsers(enabled && tab === "users");
  const pushConfigState = usePushConfig(enabled && tab === "push");

  const refreshAll = useCallback(async () => {
    await Promise.all([
      metricsState.reload(),
      restaurantsState.reload(),
      tab === "gifticons" ? gifticonsState.reload() : Promise.resolve(),
      tab === "feedback" ? feedbackState.reload() : Promise.resolve(),
      tab === "community" ? communityState.reload() : Promise.resolve(),
      tab === "users" ? usersState.reload() : Promise.resolve(),
      tab === "push" ? pushConfigState.reload() : Promise.resolve(),
    ]);
  }, [
    metricsState,
    restaurantsState,
    gifticonsState,
    feedbackState,
    communityState,
    usersState,
    pushConfigState,
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
          loading={communityState.loading}
          error={communityState.error}
          onHidePost={communityState.hidePost}
          onRemovePost={communityState.removePost}
          onHideComment={communityState.hideComment}
          onRemoveComment={communityState.removeComment}
          onAddWord={communityState.addWord}
          onRemoveWord={communityState.removeWord}
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
          if (next === "users") usersState.reload();
          if (next === "push") pushConfigState.reload();
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
