#include <jni.h>
#include <SDL3/SDL.h>
#include <string>
#include <vector>

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

// Lua state for callbacks
lua_State* g_luaState = nullptr;

static const char* const CLS_NAME = "com/tapresearch/love/TapResearchLoveBridge";

static JNIEnv* getEnv() {
    return (JNIEnv*)SDL_GetAndroidJNIEnv();
}

static jclass getBridgeClass(JNIEnv* env) {
    return env->FindClass(CLS_NAME);
}

// Helper to convert Lua table to HashMap<String, Object>
static jobject lua_to_hashmap(lua_State* L, int index) {
    JNIEnv* env = getEnv();
    jclass mapClass = env->FindClass("java/util/HashMap");
    jmethodID mapInit = env->GetMethodID(mapClass, "<init>", "()V");
    jobject hashMap = env->NewObject(mapClass, mapInit);
    jmethodID mapPut = env->GetMethodID(mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

    lua_pushnil(L);
    while (lua_next(L, index) != 0) {
        // key is at -2, value is at -1
        if (lua_type(L, -2) == LUA_TSTRING) {
            const char* key = lua_tostring(L, -2);
            jstring jKey = env->NewStringUTF(key);
            jobject jVal = nullptr;

            int type = lua_type(L, -1);
            if (type == LUA_TSTRING) {
                jVal = env->NewStringUTF(lua_tostring(L, -1));
            } else if (type == LUA_TNUMBER) {
                jclass doubleClass = env->FindClass("java/lang/Double");
                jmethodID doubleInit = env->GetMethodID(doubleClass, "<init>", "(D)V");
                jVal = env->NewObject(doubleClass, doubleInit, lua_tonumber(L, -1));
            } else if (type == LUA_TBOOLEAN) {
                jclass boolClass = env->FindClass("java/lang/Boolean");
                jmethodID boolInit = env->GetMethodID(boolClass, "<init>", "(Z)V");
                jVal = env->NewObject(boolClass, boolInit, (jboolean)lua_toboolean(L, -1));
            }

            if (jVal) {
                env->CallObjectMethod(hashMap, mapPut, jKey, jVal);
                env->DeleteLocalRef(jVal);
            }
            env->DeleteLocalRef(jKey);
        }
        lua_pop(L, 1);
    }

    env->DeleteLocalRef(mapClass);
    return hashMap;
}

//MARK: - TapResearch Initialization functions

static int l_tap_initialize(lua_State* L) {
    const char* token = luaL_checkstring(L, 1);
    const char* userId = luaL_checkstring(L, 2);
    const char* devVersion = luaL_checkstring(L, 3);
    const char* devEngineVersion = luaL_checkstring(L, 4);

    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "initialize", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");

    jstring jToken = env->NewStringUTF(token);
    jstring jUserId = env->NewStringUTF(userId);
    jstring jDevVersion = env->NewStringUTF(devVersion);
    jstring jDevEngineVersion = env->NewStringUTF(devEngineVersion);

    env->CallStaticVoidMethod(clazz, mid, jToken, jUserId, jDevVersion, jDevEngineVersion);

    env->DeleteLocalRef(jToken);
    env->DeleteLocalRef(jUserId);
    env->DeleteLocalRef(jDevVersion);
    env->DeleteLocalRef(jDevEngineVersion);
    env->DeleteLocalRef(clazz);
    return 0;
}

static int l_tap_initialize_with_user_attributes(lua_State* L) {
    const char* token = luaL_checkstring(L, 1);
    const char* userId = luaL_checkstring(L, 2);
    // Attributes table is at 3
    if (!lua_istable(L, 3)) return 0;
    jobject jMap = lua_to_hashmap(L, 3);
    jboolean jClear = (jboolean)lua_toboolean(L, 4);
    const char* devVersion = luaL_checkstring(L, 5);
    const char* devEngineVersion = luaL_checkstring(L, 6);

    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "initializeWithUserAttributes", "(Ljava/lang/String;Ljava/lang/String;Ljava/util/HashMap;ZLjava/lang/String;Ljava/lang/String;)V");

    jstring jToken = env->NewStringUTF(token);
    jstring jUserId = env->NewStringUTF(userId);
    jstring jDevVersion = env->NewStringUTF(devVersion);
    jstring jDevEngineVersion = env->NewStringUTF(devEngineVersion);

    env->CallStaticVoidMethod(clazz, mid, jToken, jUserId, jMap, jClear, jDevVersion, jDevEngineVersion);

    env->DeleteLocalRef(jToken);
    env->DeleteLocalRef(jUserId);
    env->DeleteLocalRef(jDevVersion);
    env->DeleteLocalRef(jDevEngineVersion);
    env->DeleteLocalRef(jMap);
    env->DeleteLocalRef(clazz);
    return 0;
}

static int l_tap_is_ready(lua_State* L) {
    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "isReady", "()Z");

    jboolean ready = env->CallStaticBooleanMethod(clazz, mid);

    env->DeleteLocalRef(clazz);
    lua_pushboolean(L, ready);
    return 1;
}

//MARK: - TapResearch Setter functions

static int l_tap_set_user_identifier(lua_State* L) {
    const char* userId = luaL_checkstring(L, 1);

    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "setUserIdentifier", "(Ljava/lang/String;)V");

    jstring jUserId = env->NewStringUTF(userId);
    env->CallStaticVoidMethod(clazz, mid, jUserId);

    env->DeleteLocalRef(jUserId);
    env->DeleteLocalRef(clazz);
    return 0;
}

static int l_tap_send_user_attributes(lua_State* L) {
    if (!lua_istable(L, 1)) return 0;
    bool clear = lua_toboolean(L, 2);

    JNIEnv* env = getEnv();
    jobject jMap = lua_to_hashmap(L, 1);
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "sendUserAttributes", "(Ljava/util/HashMap;Z)V");

    env->CallStaticVoidMethod(clazz, mid, jMap, (jboolean)clear);

    env->DeleteLocalRef(jMap);
    env->DeleteLocalRef(clazz);
    return 0;
}

static int l_tap_can_show(lua_State* L) {
    const char* placement = luaL_checkstring(L, 1);

    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "canShowContent", "(Ljava/lang/String;)Z");

    jstring jPlacement = env->NewStringUTF(placement);
    jboolean available = env->CallStaticBooleanMethod(clazz, mid, jPlacement);

    env->DeleteLocalRef(jPlacement);
    env->DeleteLocalRef(clazz);
    lua_pushboolean(L, available);
    return 1;
}

static int l_tap_show_content(lua_State* L) {
    const char* placement = luaL_checkstring(L, 1);

    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "showContent", "(Ljava/lang/String;)V");

    jstring jPlacement = env->NewStringUTF(placement);
    env->CallStaticVoidMethod(clazz, mid, jPlacement);

    env->DeleteLocalRef(jPlacement);
    env->DeleteLocalRef(clazz);
    return 0;
}

static int l_tap_show_content_with_custom_parameters(lua_State* L) {
    const char* placement = luaL_checkstring(L, 1);
    if (!lua_istable(L, 2)) return 0;
    jobject jMap = lua_to_hashmap(L, 2);

    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "showContentWithCustomParameters", "(Ljava/lang/String;Ljava/util/HashMap;)V");

    jstring jPlacement = env->NewStringUTF(placement);
    env->CallStaticVoidMethod(clazz, mid, jPlacement, jMap);

    env->DeleteLocalRef(jPlacement);
    env->DeleteLocalRef(jMap);
    env->DeleteLocalRef(clazz);
    return 0;
}

static int l_tap_has_surveys(lua_State* L) {
    const char* placement = luaL_checkstring(L, 1);
    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "hasSurveys", "(Ljava/lang/String;)Z");
    jstring jPlacement = env->NewStringUTF(placement);
    jboolean available = env->CallStaticBooleanMethod(clazz, mid, jPlacement);
    env->DeleteLocalRef(jPlacement);
    env->DeleteLocalRef(clazz);
    lua_pushboolean(L, available);
    return 1;
}

static int l_tap_show_survey(lua_State* L) {
    const char* surveyId = luaL_checkstring(L, 1);
    const char* placement = luaL_checkstring(L, 2);
    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "showSurvey", "(Ljava/lang/String;Ljava/lang/String;)V");
    jstring jSurveyId = env->NewStringUTF(surveyId);
    jstring jPlacement = env->NewStringUTF(placement);
    env->CallStaticVoidMethod(clazz, mid, jSurveyId, jPlacement);
    env->DeleteLocalRef(jSurveyId);
    env->DeleteLocalRef(jPlacement);
    env->DeleteLocalRef(clazz);
    return 0;
}

static int l_tap_show_survey_with_custom_parameters(lua_State* L) {
    const char* surveyId = luaL_checkstring(L, 1);
    const char* placement = luaL_checkstring(L, 2);
    if (!lua_istable(L, 3)) return 0;
    jobject jMap = lua_to_hashmap(L, 3);

    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "showSurveyWithCustomParameters", "(Ljava/lang/String;Ljava/lang/String;Ljava/util/HashMap;)V");

    jstring jSurveyId = env->NewStringUTF(surveyId);
    jstring jPlacement = env->NewStringUTF(placement);
    env->CallStaticVoidMethod(clazz, mid, jSurveyId, jPlacement, jMap);

    env->DeleteLocalRef(jSurveyId);
    env->DeleteLocalRef(jPlacement);
    env->DeleteLocalRef(jMap);
    env->DeleteLocalRef(clazz);
    return 0;
}

static int l_tap_get_surveys(lua_State* L) {
    const char* placement = luaL_checkstring(L, 1);
    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "getSurveys", "(Ljava/lang/String;)[Lcom/tapresearch/tapsdk/models/TRSurvey;");
    jstring jPlacement = env->NewStringUTF(placement);
    jobjectArray surveys = (jobjectArray)env->CallStaticObjectMethod(clazz, mid, jPlacement);

    lua_newtable(L);
    if (surveys) {
        jsize len = env->GetArrayLength(surveys);
        for (jsize i = 0; i < len; i++) {
            jobject survey = env->GetObjectArrayElement(surveys, i);
            jclass surveyClass = env->GetObjectClass(survey);
            lua_newtable(L);

            auto getStrField = [&](const char* fieldName, const char* methodName) {
                jmethodID smid = env->GetMethodID(surveyClass, methodName, "()Ljava/lang/String;");
                jstring jstr = (jstring)env->CallObjectMethod(survey, smid);
                if (jstr) {
                    const char* str = env->GetStringUTFChars(jstr, NULL);
                    lua_pushstring(L, fieldName);
                    lua_pushstring(L, str);
                    lua_settable(L, -3);
                    env->ReleaseStringUTFChars(jstr, str);
                    env->DeleteLocalRef(jstr);
                }
            };

            getStrField("surveyIdentifier", "getSurveyId");
            getStrField("currencyName", "getCurrencyName");

            jmethodID getAmountMid = env->GetMethodID(surveyClass, "getRewardAmount", "()Ljava/lang/Float;");
            jobject jAmount = env->CallObjectMethod(survey, getAmountMid);
            float amount = 0.0f;
            if (jAmount) {
                jclass floatClass = env->GetObjectClass(jAmount);
                jmethodID floatValueMid = env->GetMethodID(floatClass, "floatValue", "()F");
                amount = env->CallFloatMethod(jAmount, floatValueMid);
                env->DeleteLocalRef(floatClass);
                env->DeleteLocalRef(jAmount);
            }
            lua_pushstring(L, "rewardAmount");
            lua_pushnumber(L, amount);
            lua_settable(L, -3);

            lua_rawseti(L, -2, i + 1);
            env->DeleteLocalRef(survey);
            env->DeleteLocalRef(surveyClass);
        }
    }

    env->DeleteLocalRef(jPlacement);
    env->DeleteLocalRef(clazz);
    return 1;
}

static int l_tap_set_reward_callback(lua_State* L) {
    return 0; // Handled during initialization on Android
}

static int l_tap_set_quick_question_callback(lua_State* L) {
    return 0; // Handled during initialization on Android
}

static int l_tap_get_placement_details(lua_State* L) {
    const char* placement = luaL_checkstring(L, 1);
    JNIEnv* env = getEnv();
    jclass clazz = getBridgeClass(env);
    jmethodID mid = env->GetStaticMethodID(clazz, "getPlacementDetails", "(Ljava/lang/String;)Lcom/tapresearch/tapsdk/models/TRPlacementDetails;");
    jstring jPlacement = env->NewStringUTF(placement);
    jobject details = env->CallStaticObjectMethod(clazz, mid, jPlacement);

    if (details) {
        jclass detailsClass = env->GetObjectClass(details);
        lua_newtable(L);

        auto getStrField = [&](const char* fieldName, const char* methodName) {
            jmethodID smid = env->GetMethodID(detailsClass, methodName, "()Ljava/lang/String;");
            jstring jstr = (jstring)env->CallObjectMethod(details, smid);
            if (jstr) {
                const char* str = env->GetStringUTFChars(jstr, NULL);
                lua_pushstring(L, fieldName);
                lua_pushstring(L, str);
                lua_settable(L, -3);
                env->ReleaseStringUTFChars(jstr, str);
                env->DeleteLocalRef(jstr);
            }
        };

        auto getBoolField = [&](const char* fieldName, const char* methodName) {
            jmethodID bmid = env->GetMethodID(detailsClass, methodName, "()Ljava/lang/Boolean;");
            jobject jbool = env->CallObjectMethod(details, bmid);
            if (jbool) {
                jclass boolClass = env->FindClass("java/lang/Boolean");
                jmethodID boolValueMid = env->GetMethodID(boolClass, "booleanValue", "()Z");
                bool val = env->CallBooleanMethod(jbool, boolValueMid);
                lua_pushstring(L, fieldName);
                lua_pushboolean(L, val);
                lua_settable(L, -3);
                env->DeleteLocalRef(jbool);
                env->DeleteLocalRef(boolClass);
            }
        };

        getStrField("name", "getName");
        getStrField("contentType", "getContentType");
        getStrField("currencyName", "getCurrencyName");
        getBoolField("isSale", "isSale");
        getStrField("saleType", "getSaleType");
        getStrField("saleEndDate", "getSaleEndDate");
        getStrField("saleDisplayName", "getSaleDisplayName");
        getStrField("saleTag", "getSaleTag");

        jmethodID getMultiplierMid = env->GetMethodID(detailsClass, "getSaleMultiplier", "()Ljava/lang/Float;");
        jobject jMultiplier = env->CallObjectMethod(details, getMultiplierMid);
        if (jMultiplier) {
            jclass floatClass = env->GetObjectClass(jMultiplier);
            jmethodID floatValueMid = env->GetMethodID(floatClass, "floatValue", "()F");
            float mult = env->CallFloatMethod(jMultiplier, floatValueMid);
            lua_pushstring(L, "saleMultiplier");
            lua_pushnumber(L, mult);
            lua_settable(L, -3);
            env->DeleteLocalRef(floatClass);
            env->DeleteLocalRef(jMultiplier);
        }

        env->DeleteLocalRef(detailsClass);
        env->DeleteLocalRef(details);
    } else {
        lua_pushnil(L);
    }

    env->DeleteLocalRef(jPlacement);
    env->DeleteLocalRef(clazz);
    return 1;
}

//MARK: - Register functions

extern "C" int luaopen_tapresearch_native(lua_State* L) {
    g_luaState = L;
    luaL_Reg funcs[] = {
        {"initialize", l_tap_initialize},
        {"initializeWithUserAttributes", l_tap_initialize_with_user_attributes},
        {"isReady", l_tap_is_ready},
        {"setUserIdentifier", l_tap_set_user_identifier},
        {"sendUserAttributes", l_tap_send_user_attributes},
        {"canShow", l_tap_can_show},
        {"showContent", l_tap_show_content},
        {"showContentWithCustomParameters", l_tap_show_content_with_custom_parameters},
        {"hasSurveys", l_tap_has_surveys},
        {"showSurvey", l_tap_show_survey},
        {"showSurveyWithCustomParameters", l_tap_show_survey_with_custom_parameters},
        {"getSurveys", l_tap_get_surveys},
        {"getPlacementDetails", l_tap_get_placement_details},
        {"setRewardCallback", l_tap_set_reward_callback},
        {"setQuickQuestionCallback", l_tap_set_quick_question_callback},
        {NULL, NULL}
    };
    luaL_newlib(L, funcs);
    return 1;
}

//MARK: - JNI Callback Implementations

extern "C" {

JNIEXPORT void JNICALL Java_com_tapresearch_love_TapResearchLoveBridge_nativeOnSdkReady(JNIEnv* env, jclass clazz) {
    if (g_luaState) {
        lua_getglobal(g_luaState, "require");
        lua_pushstring(g_luaState, "tapresearch");
        lua_call(g_luaState, 1, 1);

        lua_getfield(g_luaState, -1, "onSdkReady");
        if (lua_isfunction(g_luaState, -1)) {
            lua_call(g_luaState, 0, 0);
        }
        lua_pop(g_luaState, 1);
    }
}

JNIEXPORT void JNICALL Java_com_tapresearch_love_TapResearchLoveBridge_nativeOnSdkError(JNIEnv* env, jclass clazz, jstring message, jint code) {
    if (g_luaState) {
        const char* msg = env->GetStringUTFChars(message, NULL);

        lua_getglobal(g_luaState, "require");
        lua_pushstring(g_luaState, "tapresearch");
        lua_call(g_luaState, 1, 1);

        lua_getfield(g_luaState, -1, "onSdkError");
        if (lua_isfunction(g_luaState, -1)) {
            lua_pushstring(g_luaState, msg);
            lua_pushinteger(g_luaState, code);
            lua_call(g_luaState, 2, 0);
        }
        lua_pop(g_luaState, 1);

        env->ReleaseStringUTFChars(message, msg);
    }
}

JNIEXPORT void JNICALL Java_com_tapresearch_love_TapResearchLoveBridge_nativeOnContentShown(JNIEnv* env, jclass clazz, jstring placementTag) {
    if (g_luaState) {
        const char* tag = env->GetStringUTFChars(placementTag, NULL);

        lua_getglobal(g_luaState, "require");
        lua_pushstring(g_luaState, "tapresearch");
        lua_call(g_luaState, 1, 1);

        lua_getfield(g_luaState, -1, "onContentShown");
        if (lua_isfunction(g_luaState, -1)) {
            lua_pushstring(g_luaState, tag);
            lua_call(g_luaState, 1, 0);
        }
        lua_pop(g_luaState, 1);

        env->ReleaseStringUTFChars(placementTag, tag);
    }
}

JNIEXPORT void JNICALL Java_com_tapresearch_love_TapResearchLoveBridge_nativeOnContentDismissed(JNIEnv* env, jclass clazz, jstring placementTag) {
    if (g_luaState) {
        const char* tag = env->GetStringUTFChars(placementTag, NULL);

        lua_getglobal(g_luaState, "require");
        lua_pushstring(g_luaState, "tapresearch");
        lua_call(g_luaState, 1, 1);

        lua_getfield(g_luaState, -1, "onContentDismissed");
        if (lua_isfunction(g_luaState, -1)) {
            lua_pushstring(g_luaState, tag);
            lua_call(g_luaState, 1, 0);
        }
        lua_pop(g_luaState, 1);

        env->ReleaseStringUTFChars(placementTag, tag);
    }
}

JNIEXPORT void JNICALL Java_com_tapresearch_love_TapResearchLoveBridge_nativeOnRewardReceived(JNIEnv* env, jclass clazz, jobjectArray rewards) {
    if (g_luaState) {
        lua_State* L = g_luaState;
        lua_getglobal(L, "require");
        lua_pushstring(L, "tapresearch");
        lua_call(L, 1, 1);

        lua_getfield(L, -1, "onRewardReceived");
        if (lua_isfunction(L, -1)) {
            jsize len = env->GetArrayLength(rewards);
            lua_newtable(L);
            for (jsize i = 0; i < len; i++) {
                jobject reward = env->GetObjectArrayElement(rewards, i);
                jclass rewardClass = env->GetObjectClass(reward);

                lua_newtable(L);

                auto getStrField = [&](const char* fieldName, const char* methodName) {
                    jmethodID mid = env->GetMethodID(rewardClass, methodName, "()Ljava/lang/String;");
                    if (env->ExceptionCheck()) {
                        env->ExceptionClear();
                        return;
                    }
                    if (mid) {
                        jstring jstr = (jstring)env->CallObjectMethod(reward, mid);
                        if (env->ExceptionCheck()) {
                            env->ExceptionClear();
                            return;
                        }
                        if (jstr) {
                            const char* str = env->GetStringUTFChars(jstr, NULL);
                            lua_pushstring(L, fieldName);
                            lua_pushstring(L, str);
                            lua_settable(L, -3);
                            env->ReleaseStringUTFChars(jstr, str);
                            env->DeleteLocalRef(jstr);
                        }
                    }
                };

                getStrField("transactionIdentifier", "getTransactionIdentifier");
                getStrField("currencyName", "getCurrencyName");
                getStrField("placementTag", "getPlacementTag");
                getStrField("placementIdentifier", "getPlacementIdentifier");
                getStrField("payoutEvent", "getPayoutEventType");

                jmethodID getAmountMid = env->GetMethodID(rewardClass, "getRewardAmount", "()Ljava/lang/Float;");
                jobject jAmount = env->CallObjectMethod(reward, getAmountMid);
                float amount = 0.0f;
                if (jAmount) {
                    jclass floatClass = env->GetObjectClass(jAmount);
                    jmethodID floatValueMid = env->GetMethodID(floatClass, "floatValue", "()F");
                    amount = env->CallFloatMethod(jAmount, floatValueMid);
                    env->DeleteLocalRef(floatClass);
                    env->DeleteLocalRef(jAmount);
                }
                lua_pushstring(L, "rewardAmount");
                lua_pushnumber(L, amount);
                lua_settable(L, -3);

                lua_rawseti(L, -2, i + 1);
                env->DeleteLocalRef(reward);
                env->DeleteLocalRef(rewardClass);
            }
            lua_call(L, 1, 0);
        } else {
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
    }
}

JNIEXPORT void JNICALL Java_com_tapresearch_love_TapResearchLoveBridge_nativeOnQuickQuestionResponse(JNIEnv* env, jclass clazz, jobject payload) {
    if (g_luaState && payload) {
        lua_State* L = g_luaState;
        lua_getglobal(L, "require");
        lua_pushstring(L, "tapresearch");
        lua_call(L, 1, 1);

        lua_getfield(L, -1, "onQuickQuestionResponse");
        if (lua_isfunction(L, -1)) {
            jclass qqClass = env->GetObjectClass(payload);
            lua_newtable(L);

            auto getStrField = [&](const char* fieldName, const char* methodName) {
                jmethodID mid = env->GetMethodID(qqClass, methodName, "()Ljava/lang/String;");
                if (env->ExceptionCheck()) {
                    env->ExceptionClear();
                    return;
                }
                if (mid) {
                    jstring jstr = (jstring)env->CallObjectMethod(payload, mid);
                    if (env->ExceptionCheck()) {
                        env->ExceptionClear();
                        return;
                    }
                    if (jstr) {
                        const char* str = env->GetStringUTFChars(jstr, NULL);
                        lua_pushstring(L, fieldName);
                        lua_pushstring(L, str);
                        lua_settable(L, -3);
                        env->ReleaseStringUTFChars(jstr, str);
                        env->DeleteLocalRef(jstr);
                    }
                }
            };

            // Map Java camelCase getters to Lua snake_case as expected by main.lua
            getStrField("survey_identifier", "getSurveyIdentifier");
            getStrField("app_name", "getAppName");
            getStrField("sdk_version", "getSdkVersion");
            getStrField("platform", "getPlatform");
            getStrField("placement_tag", "getPlacementTag");
            getStrField("user_identifier", "getUserIdentifier");
            getStrField("user_locale", "getUserLocale");
            getStrField("seen_at", "getSeenAt");

            // Handle "questions" list
            jmethodID getQuestionsMid = env->GetMethodID(qqClass, "getQuestions", "()Ljava/util/List;");
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
            } else if (getQuestionsMid) {
                jobject questionsList = env->CallObjectMethod(payload, getQuestionsMid);
                if (questionsList) {
                    jclass listClass = env->FindClass("java/util/List");
                    jmethodID sizeMid = env->GetMethodID(listClass, "size", "()I");
                    jint size = env->CallIntMethod(questionsList, sizeMid);

                    if (size > 0) {
                        lua_pushstring(L, "questions");
                        lua_newtable(L);

                        jmethodID getMid = env->GetMethodID(listClass, "get", "(I)Ljava/lang/Object;");
                        for (int i = 0; i < size; i++) {
                            jobject questionObj = env->CallObjectMethod(questionsList, getMid, i);
                            if (questionObj) {
                                jclass questionClass = env->GetObjectClass(questionObj);
                                lua_newtable(L);

                                auto getQStrField = [&](const char* fName, const char* mName) {
                                    jmethodID qMid = env->GetMethodID(questionClass, mName, "()Ljava/lang/String;");
                                    if (env->ExceptionCheck()) { env->ExceptionClear(); return; }
                                    if (qMid) {
                                        jstring qJStr = (jstring)env->CallObjectMethod(questionObj, qMid);
                                        if (qJStr) {
                                            const char* qStr = env->GetStringUTFChars(qJStr, NULL);
                                            lua_pushstring(L, fName);
                                            lua_pushstring(L, qStr);
                                            lua_settable(L, -3);
                                            env->ReleaseStringUTFChars(qJStr, qStr);
                                            env->DeleteLocalRef(qJStr);
                                        }
                                    }
                                };

                                getQStrField("question_identifier", "getQuestionIdentifier");
                                getQStrField("question_text", "getQuestionText");
                                getQStrField("question_type", "getQuestionType");

                                // Handle UserAnswer if it exists
                                jmethodID getUserAnswerMid = env->GetMethodID(questionClass, "getUserAnswer", "()Lcom/tapresearch/tapsdk/models/UserAnswer;");
                                if (env->ExceptionCheck()) {
                                    env->ExceptionClear();
                                } else if (getUserAnswerMid) {
                                    jobject userAnswerObj = env->CallObjectMethod(questionObj, getUserAnswerMid);
                                    if (userAnswerObj) {
                                        lua_pushstring(L, "user_answer");
                                        lua_newtable(L);
                                        jclass uaClass = env->GetObjectClass(userAnswerObj);

                                        jmethodID getValueMid = env->GetMethodID(uaClass, "getValue", "()Ljava/lang/String;");
                                        if (getValueMid) {
                                            jstring valJStr = (jstring)env->CallObjectMethod(userAnswerObj, getValueMid);
                                            if (valJStr) {
                                                const char* valStr = env->GetStringUTFChars(valJStr, NULL);
                                                lua_pushstring(L, "value");
                                                lua_pushstring(L, valStr);
                                                lua_settable(L, -3);
                                                env->ReleaseStringUTFChars(valJStr, valStr);
                                                env->DeleteLocalRef(valJStr);
                                            }
                                        }

                                        // Handle identifiers list in UserAnswer
                                        jmethodID getIdsMid = env->GetMethodID(uaClass, "getIdentifiers", "()Ljava/util/List;");
                                        if (getIdsMid) {
                                            jobject idsList = env->CallObjectMethod(userAnswerObj, getIdsMid);
                                            if (idsList) {
                                                jclass idsListClass = env->FindClass("java/util/List");
                                                jmethodID idsSizeMid = env->GetMethodID(idsListClass, "size", "()I");
                                                jint idsSize = env->CallIntMethod(idsList, idsSizeMid);
                                                if (idsSize > 0) {
                                                    lua_pushstring(L, "identifiers");
                                                    lua_newtable(L);
                                                    jmethodID idsGetMid = env->GetMethodID(idsListClass, "get", "(I)Ljava/lang/Object;");
                                                    for (int j = 0; j < idsSize; j++) {
                                                        jstring idJStr = (jstring)env->CallObjectMethod(idsList, idsGetMid, j);
                                                        if (idJStr) {
                                                            const char* idStr = env->GetStringUTFChars(idJStr, NULL);
                                                            lua_pushstring(L, idStr);
                                                            lua_rawseti(L, -2, j + 1);
                                                            env->ReleaseStringUTFChars(idJStr, idStr);
                                                            env->DeleteLocalRef(idJStr);
                                                        }
                                                    }
                                                    lua_settable(L, -3);
                                                }
                                                env->DeleteLocalRef(idsListClass);
                                                env->DeleteLocalRef(idsList);
                                            }
                                        }
                                        lua_settable(L, -3);
                                        env->DeleteLocalRef(uaClass);
                                        env->DeleteLocalRef(userAnswerObj);
                                    }
                                }

                                lua_rawseti(L, -2, i + 1);
                                env->DeleteLocalRef(questionClass);
                                env->DeleteLocalRef(questionObj);
                            }
                        }
                        lua_settable(L, -3);
                    }
                    env->DeleteLocalRef(listClass);
                    env->DeleteLocalRef(questionsList);
                }
            }

            lua_call(L, 1, 0);
            env->DeleteLocalRef(qqClass);
        } else {
            lua_pop(L, 1);
        }
        lua_pop(L, 1);
    }
}

} // extern "C"
