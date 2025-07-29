package dev.fluttercommunity.workmanager

import android.content.Context
import android.content.SharedPreferences
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.junit.MockitoJUnitRunner
import org.mockito.kotlin.any
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

@RunWith(MockitoJUnitRunner::class)
class SharedPreferenceHelperTest {
    @Mock
    private lateinit var mockContext: Context

    @Mock
    private lateinit var mockSharedPreferences: SharedPreferences

    @Mock
    private lateinit var mockEditor: SharedPreferences.Editor

    @Mock
    private lateinit var mockListener: SharedPreferenceHelper.DispatcherHandleListener

    private companion object {
        const val SHARED_PREFS_FILE_NAME = "flutter_workmanager_plugin"
        const val CALLBACK_DISPATCHER_HANDLE_KEY = "dev.fluttercommunity.workmanager.CALLBACK_DISPATCHER_HANDLE_KEY"
        const val TEST_HANDLE = 12345L
        const val INVALID_HANDLE = -1L
    }

    @Before
    fun setUp() {
        whenever(mockContext.getSharedPreferences(SHARED_PREFS_FILE_NAME, Context.MODE_PRIVATE))
            .thenReturn(mockSharedPreferences)
        whenever(mockSharedPreferences.edit()).thenReturn(mockEditor)
        whenever(mockEditor.putLong(any(), any())).thenReturn(mockEditor)
    }

    @Test
    fun `init should call callback immediately when preferences already exist`() {
        // Given: preferences already contain a valid handle
        whenever(mockSharedPreferences.getLong(CALLBACK_DISPATCHER_HANDLE_KEY, INVALID_HANDLE))
            .thenReturn(TEST_HANDLE)

        // When: SharedPreferenceHelper is initialized
        SharedPreferenceHelper(mockContext, mockListener)

        // Then: callback should be called immediately with the existing handle
        verify(mockListener).onDispatcherHandleChanged(TEST_HANDLE)
        verify(mockSharedPreferences).registerOnSharedPreferenceChangeListener(any())
    }

    @Test
    fun `init should not call callback when preferences do not exist`() {
        // Given: preferences contain invalid handle (-1L)
        whenever(mockSharedPreferences.getLong(CALLBACK_DISPATCHER_HANDLE_KEY, INVALID_HANDLE))
            .thenReturn(INVALID_HANDLE)

        // When: SharedPreferenceHelper is initialized
        SharedPreferenceHelper(mockContext, mockListener)

        // Then: callback should not be called
        verify(mockListener, never()).onDispatcherHandleChanged(any())
        verify(mockSharedPreferences).registerOnSharedPreferenceChangeListener(any())
    }

    @Test
    fun `saveCallbackDispatcherHandleKey should save handle to preferences`() {
        // Given: SharedPreferenceHelper is initialized
        whenever(mockSharedPreferences.getLong(CALLBACK_DISPATCHER_HANDLE_KEY, INVALID_HANDLE))
            .thenReturn(INVALID_HANDLE)
        val helper = SharedPreferenceHelper(mockContext, mockListener)

        // When: saving a callback handle
        helper.saveCallbackDispatcherHandleKey(TEST_HANDLE)

        // Then: handle should be saved to preferences
        verify(mockEditor).putLong(CALLBACK_DISPATCHER_HANDLE_KEY, TEST_HANDLE)
    }

    @Test
    fun `preference change listener should trigger callback when handle key changes`() {
        // Given: SharedPreferenceHelper is initialized and we capture the listener
        whenever(mockSharedPreferences.getLong(CALLBACK_DISPATCHER_HANDLE_KEY, INVALID_HANDLE))
            .thenReturn(INVALID_HANDLE)

        var capturedListener: SharedPreferences.OnSharedPreferenceChangeListener? = null
        whenever(mockSharedPreferences.registerOnSharedPreferenceChangeListener(any())).then { invocation ->
            capturedListener = invocation.getArgument(0)
            null
        }

        SharedPreferenceHelper(mockContext, mockListener)

        // When: preference changes for the callback dispatcher handle key
        whenever(mockSharedPreferences.getLong(CALLBACK_DISPATCHER_HANDLE_KEY, INVALID_HANDLE))
            .thenReturn(TEST_HANDLE)
        capturedListener?.onSharedPreferenceChanged(mockSharedPreferences, CALLBACK_DISPATCHER_HANDLE_KEY)

        // Then: callback should be triggered with the new handle
        verify(mockListener).onDispatcherHandleChanged(TEST_HANDLE)
    }

    @Test
    fun `preference change listener should not trigger callback for other keys`() {
        // Given: SharedPreferenceHelper is initialized and we capture the listener
        whenever(mockSharedPreferences.getLong(CALLBACK_DISPATCHER_HANDLE_KEY, INVALID_HANDLE))
            .thenReturn(INVALID_HANDLE)

        var capturedListener: SharedPreferences.OnSharedPreferenceChangeListener? = null
        whenever(mockSharedPreferences.registerOnSharedPreferenceChangeListener(any())).then { invocation ->
            capturedListener = invocation.getArgument(0)
            null
        }

        SharedPreferenceHelper(mockContext, mockListener)

        // When: preference changes for a different key
        capturedListener?.onSharedPreferenceChanged(mockSharedPreferences, "some_other_key")

        // Then: callback should not be triggered
        verify(mockListener, never()).onDispatcherHandleChanged(any())
    }

    @Test
    fun `getCallbackHandle should return handle from preferences`() {
        // Given: preferences contain a handle
        whenever(mockSharedPreferences.getLong(CALLBACK_DISPATCHER_HANDLE_KEY, INVALID_HANDLE))
            .thenReturn(TEST_HANDLE)

        // When: getting callback handle
        val result = SharedPreferenceHelper.getCallbackHandle(mockContext)

        // Then: should return the stored handle
        assert(result == TEST_HANDLE)
    }

    @Test
    fun `getCallbackHandle should return -1 when no handle exists`() {
        // Given: preferences contain no handle
        whenever(mockSharedPreferences.getLong(CALLBACK_DISPATCHER_HANDLE_KEY, INVALID_HANDLE))
            .thenReturn(INVALID_HANDLE)

        // When: getting callback handle
        val result = SharedPreferenceHelper.getCallbackHandle(mockContext)

        // Then: should return -1
        assert(result == INVALID_HANDLE)
    }
}
